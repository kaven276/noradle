var cfg = require('./cfg.js')
  , DBInMgr = require('./db.js')
  , ReqBase = require('./ReqBase.js')
  , req_oracle = require('./req_oracle.js').http2oracle
  , logger = require('./logger.js')
  , CRLF = '\r\n'
  , curFeedbackSeq = 0
  , fbSocks = {}
  , cssSocks = {}
  , favicon = require('./favicon.js')
  , errmsg
  , zip = require('./zip.js')
  , chooseZip = zip.chooseZip
  , zipMap = zip.zipMap
  , MD5Calc = require('./MD5Calc.js').Class
  , Cache = require('./Cache.js')
  , monitor = require('./monitor.js')
  , stat = monitor.stat
  , endMark = 'EOF'
  , guidMgr = require('./guidMgr.js')
  , fmt = require('util').format
  , utl = require('./util.js')
  , base64alt = utl.base64alt
  ;

function parseCookie(req){
  var cookies = {}
    , hdrCookie = req.headers.cookie
    , nv
    ;
  hdrCookie && hdrCookie.split(/[;,] */).forEach(function(cookie){
    nv = cookie.split(/\s*=\s*/);
    cookies[nv[0]] = nv[1];
  });
  return cookies;
}

function pspdweb(req, res, next){
  var oraHeaderEnd = false
    , reqNo = ++stat.allCnt
    , reqUrl = req.originUrl || req.url
    , follow = false
    , normalReq
    , cookies
    , oraSock
    , busyRec
    , bytesRead = 0
    , cLen
    , fbseq
    , cssmd5
    , bakRes = res
    , compress
    , buffered_response = false
    , md5val
    , cachedEntity
    , md5Content
    , ohdr = {
      'x-powered-by' : cfg.server_name || 'Noradle - PSP.WEB'
    };

  logger.turn('-> %d %s', reqNo, reqUrl);

  if (reqUrl === '/server-status') {
    monitor.showStatus(req, res);
    return;
  }

  // res.socket.setNoDelay();
  if (favicon(req, res)) return;

  var rb = new ReqBase(req);

  switch (rb.prog) {

    case 'feedback' :
      stat.fbCnt++;
      fbseq = parseInt(rb.search.split('=')[1]);
      busyRec = fbSocks[fbseq];
      busyRec.following = true;
      oraSock = busyRec.oraSock;
      if (oraSock) {
        delete fbSocks[fbseq];
        oraSock.write('feedback' + CRLF);
        ohdr['ETag'] = '"' + fbseq + '"';
        ohdr['Cache-Control'] = 'max-age=600';
        oraSock.on('data', accept_oracle_data);
      } else {
        if (req.headers['if-none-match']) {
          res.writeHead(304, {});
          res.end();
        } else if (oraSock === false) {
          res.writeHead(500, {});
          res.end('too long after the page redirecting to this feedback page send the request, the feedback is removed from server after timeout');
        } else {
          res.writeHead(400, {});
          res.end('please donnot refresh the feedback page manually!');
        }
      }
      break;

    case 'css' :
      stat.cssCnt++;
      cssmd5 = rb.path;
      busyRec = cssSocks[cssmd5].pop();
      busyRec.following = true;
      oraSock = busyRec.oraSock;
      if (oraSock) {
        // todo: need to lookup the oraSock status, if it's really free at the moment, or timeout by monitor
        oraSock.write('csslink' + CRLF);
        ohdr['ETag'] = '"' + cssmd5 + '"';
        ohdr['Cache-Control'] = 'max-age=60000';
        oraSock.on('data', accept_oracle_data);
      } else {
        if (req.headers['if-none-match']) {
          res.writeHead(304, {});
          res.end();
        } else if (oraSock === false) {
          res.writeHead(500, {});
          res.end('too long after the page owning the css send the request, the css is removed from server after timeout');
          return;
        }
        res.writeHead(400, {});
        res.end('please donnot refresh the css manually!');
      }
      break;

    default:
      stat.reqCnt++;
      normalReq = true;
      cookies = parseCookie(req);
      if (ensureSID() === false) {
        return;
      }
      DBInMgr.findFreeOraSockThen(reqUrl, req.connection, function(c, br){
        if (c) {
          oraSock = c;
          busyRec = br;
          req_oracle(req, rb, cookies, oraSock, next);
          oraSock.on('data', accept_oracle_data);
          oraSock.on('timeout', function(interval){
            errmsg = 'execute over ' + interval + ' milliseconds and nothing response received!';
            res.writeHead(504, 'Gateway Timeout', {
              'Content-Length' : errmsg.length,
              'Content-Type' : 'text/plain',
              'Retry-After' : '3'
            });
            res.end(errmsg);
          });
        } else {
          // console.log('no database server connection/process available');
          errmsg = 'waiting for free database connection timeout';
          res.writeHead(503, 'Service Unavailable', {
            'Content-Length' : errmsg.length,
            'Content-Type' : 'text/plain',
            'Retry-After' : '3'
          });
          res.end(errmsg);
        }
      });
  }

  function ensureSID(){
    var host = req.headers.host
      , fstReq = (res.socket._bytesDispatched === 0)
      , msid = cookies['MSID']
      , bsid = cookies['BSID']
      , isNew = !bsid
      , ua = req.headers['user-agent']
      , uaHash = utl.hash2(ua)
      , setCookies = []
      ;

    ohdr['Set-Cookie'] = setCookies;
    // UA is not browser and not require session or browser not allow cookie
    if (ua.match(cfg.NoneBrowserPattern) || !fstReq) {
      tellOracle();
      return true;
    }

    function computeHost(){
      if (host) {
        host = host.split(':')[0];
        if (host && host.slice(-1).match(/\d/)) {
          host = '';
        } else {
          host = host.split('.').slice(-2).join('.')
        }
      }
    }

    function getStripe(){
      var host = req.headers.host;
      if (host) {
        return host;
      } else {
        var addr = req.socket.address();
        return [ addr.address, addr.port].join(':');
      }
    }

    function tellOracle(){
      rb.setSid(bsid || '', msid || '', uaHash || '');
    }

    if (bsid) {
      delete req.headers['user-agent'];
    }

    if (!msid || !bsid) {
      computeHost();
      if (!msid) {
        msid = guidMgr.create();
        var tEnd = new Date(Date.UTC(9999, 1, 1, 0, 0, 0, 0)).toGMTString();
        setCookies.push(fmt('MSID=%s%s;Version=1;Max-Age=%s;Path=/', msid, host ? (';Domain=.' + host) : '', 10000 * 24 * 60 * 60));
      }
      if (!bsid) {
        bsid = guidMgr.create(getStripe());
        setCookies.push(fmt('BSID=%s%s;Version=1;Path=/', bsid, host ? (';Domain=.' + host) : ''));
      }
    }

    tellOracle();
  }

  function accept_oracle_data(data){
    try {
      // console.log('received count = ' + (++rcv_cnt));
      // console.log('\n-- received following oracle response data');
      (oraHeaderEnd ? (cLen ? writeToLength : writeToMarker) : process_header)(data);
    } catch (e) {
      // todo: release resources and write log
      if (next)
        next(e);
      else
        throw e;
    }
  }

  function process_header(data){
    logger.turn('<- %d first respond', reqNo);
    logger.oraResp(data.toString());
    var hLen = parseInt(data.slice(0, 5).toString('utf8'), 10);
    logger.oraResp("oracle response header length = " + data.slice(0, 5).toString('utf8'));
    var oraResHead = data.slice(5, 5 + hLen - 2).toString('utf8').split(CRLF);
    logger.oraResp(oraResHead);
    var bodyChunk = data.slice(5 + hLen, data.length);
    var status = oraResHead[0];
    for (var i = 1; i < oraResHead.length; i++) {
      var nv = oraResHead[i].split(": ");
      if (nv[0] === 'Set-Cookie') {
        if (ohdr[nv[0]]) ohdr['Set-Cookie'].push(nv[1]);
        else ohdr['Set-Cookie'] = [nv[1]];
      } else {
        ohdr[nv[0]] = nv[1];
      }
    }

    // cause feedback to follow in the same oraSock
    if (ohdr.Location && ohdr.Location.substr(0, 12) === 'feedback?id=') {
      ohdr.Location += (++curFeedbackSeq);
      res.writeHead(status, ohdr);
      res.end();
      follow = true;
      fbSocks[curFeedbackSeq] = busyRec;
      fin();
      return;
    }

    // cause css link to follow in the same oraSock
    if (css_md5 = ohdr['x-css-md5']) {
      follow = true;
      if (cssSocks[css_md5]) {
        cssSocks[css_md5].push(busyRec);
      } else {
        cssSocks[css_md5] = [busyRec];
      }
    }

    if (cLen = ohdr['Content-Length']) {
      cLen = parseInt(cLen);
    }

    if (normalReq && cfg.use_gw_cache && ohdr['ETag'] && status != 304) {
      md5val = ohdr['ETag'].substr(1, 24);
      if (cachedEntity = Cache.findCacheHit(req.url, md5val)) {
        oraSock.write('Cache Hit' + CRLF);
        cachedEntity.respond(req, res);
        DBInMgr.pushBackToFreelist(oraSock);
        return;
      } else {
        oraSock.write('Cache Miss' + CRLF);
        // todo : save http response header and body in cache
        md5Content = new Cache.MD5Content(md5val, ohdr, cLen);
        ohdr['x-pw-noradle-cache'] = 'miss';
      }
    }

    if (ohdr['Content-MD5'] === '?') {
      buffered_response = true;
      res = new MD5Calc(function(len, md5, chunks){
        res = bakRes;
        delete ohdr['Transfer-Encoding'];
        ohdr['Content-Length'] = len;
        ohdr['Content-MD5'] = md5;
        res.writeHead(status, ohdr);
        chunks.forEach(function(chunk){
          res.write(chunk);
        });
        res.end();
      });
    }

    if ((compress = chooseZip(req)) &&
      (ohdr['Content-Encoding'] === 'zip' || (ohdr['Content-Encoding'] === '?' && (cLen || -1) > cfg.zip_threshold))) {
      ohdr['Content-Encoding'] = compress;
      // todo: remember to write x-pw-gzip-ratio as trailer
      if (ohdr['Content-Length']) {
        ohdr['x-pw-content-length'] = ohdr['Content-Length'];
        delete ohdr['Content-Length'];
        ohdr['Transfer-Encoding'] = 'chunked';
      }
      compress = zipMap[compress]();
      compress.pipe(res);
      res = compress;
    } else {
      delete ohdr['Content-Encoding'];
    }
    buffered_response || bakRes.writeHead(status, ohdr);
    oraHeaderEnd = true;
    logger.oraResp(ohdr);

    if (cLen === 0) {
      res.end();
      logger.oraResp('\n-- end response with zero content length --');
      fin();
      return;
    }

    if (bodyChunk.length) {
      logger.oraResp('\nfirst chunk has http header and parts of http body !');
      logger.oraResp('coupled http body size is %d', bodyChunk.length);
      if (cLen) {
        writeToLength(bodyChunk);
      } else {
        writeToMarker(bodyChunk);
      }
    }
  }

  function fin(){
    logger.turn('<= %d finished', reqNo);
    if (follow) {
      oraSock.removeListener('data', accept_oracle_data);
      busyRec.halfWayTime = Date.now();
    } else {
      DBInMgr.pushBackToFreelist(oraSock, busyRec);
    }
  }

  function writeToMarker(data){
    logger.oraResp('writeToMarker', data.length);
    var bLen = data.length;
    if (data.slice(bLen - endMark.length).toString('utf8') !== endMark) {
      res.write(data);
      md5Content && md5Content.write(data);
    } else {
      res.end(data.slice(0, bLen - endMark.length));
      md5Content && md5Content.end(data.slice(0, bLen - endMark.length));
      logger.oraResp('\n-- end response with marker --');
      fin();
    }
  }

  function writeToLength(data){
    logger.oraResp('writeToLength', data.length);
    bytesRead += data.length;
    logger.turn('<- %d received chunk %d/%d. cLen=%d', reqNo, data.length, bytesRead, cLen);
    if (bytesRead < cLen) {
      res.write(data);
      md5Content && md5Content.write(data);
    } else if (bytesRead === cLen) {
      res.end(data);
      md5Content && md5Content.end(data);
      // oraSock.pause();
      fin();
    } else {
      console.error(data.toString());
      DBInMgr.reportProtocolError(oraSock, busyRec);
      var errmsg = 'received data is more than Content-Length header said';
      res.writeHead(500, 'Internal Server Error', {
        'Content-Length' : errmsg.length,
        'Content-Type' : 'text/plain',
        'Retry-After' : '3'
      });
      res.end(errmsg);
    }
  }
}

module.exports = exports = pspdweb;


