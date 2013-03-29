var cfg = require('./cfg.js')
  , inspect = require('util').inspect
  , DBInMgr = require('./db.js')
  , ReqBase = require('./ReqBase.js')
  , req_oracle = require('./req_oracle.js').http2oracle
  , logger = require('./logger.js')
  , CRLF = '\r\n'
  , curFeedbackSeq = 0
  , fbBuffer = {}
  , cssBuffer = {}
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
  , mGuard = require('./SidGuard.js')
  ;

function FBItem(status, headers){
  this.status = status;
  this.headers = headers;
  this.chunks = [];
}

function CSSItem(status, headers){
  this.status = status;
  this.headers = headers;
  this.chunks = [];
}

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
  var reqNo = ++stat.allCnt
    , reqUrl = req.originUrl || req.url
    , follows
    , normalReq
    , cookies
    , oraSock
    , busyRec
    , bytesRead = 0
    , cLen
    , fbId
    , fbItem
    , cssmd5
    , cssItem
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
      fbItem = fbBuffer[fbseq];
      if (fbItem) {
        delete fbBuffer[fbseq];
        fbItem.headers['ETag'] = '"' + fbseq + '"';
        fbItem.headers['Cache-Control'] = 'max-age=600';
        res.writeHead(fbItem.status, fbItem.headers);
        fbItem.chunks.forEach(function(chunk){
          res.write(chunk);
        });
        res.end();
      } else {
        if (req.headers['if-none-match']) {
          res.writeHead(304, {});
          res.end();
        } else if (!fbItem) {
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
      cssItem = cssBuffer[cssmd5];
      if (cssItem) {
        // todo: need to lookup the oraSock status, if it's really free at the moment, or timeout by monitor
        delete cssBuffer[cssmd5];
        cssItem.headers['ETag'] = '"' + cssmd5 + '"';
        cssItem.headers['Cache-Control'] = 'max-age=60000';
        res.writeHead(cssItem.status, cssItem.headers);
        cssItem.chunks.forEach(function(chunk){
          res.write(chunk);
        });
        res.end();
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
      , port = rb.port
      , fstReq = (res.socket._bytesDispatched === 0)
      , msid = cookies['MSID']
      , bsid = cookies['BSID']
      , guard = cookies['GUARD' + port]
      , newGuard
      , ua = req.headers['user-agent'] || ''
      , uaHash = utl.hash2(ua)
      , setCookies = []
      , writeHead
      ;

    delete cookies['GUARD' + port];
    ohdr['Set-Cookie'] = setCookies;

    if (bsid && cfg.check_session_hijack) {
      try {
        if (newGuard = mGuard.checkUpdate(host, bsid, guard, rb.caddr)) {
          writeHead = bakRes.writeHead;
          bakRes.writeHead = function(sts, headers){
            if (typeof newGuard === 'function') {
              newGuard = newGuard();
            }
            ohdr['Set-Cookie'].push(fmt('GUARD%d=%s;Version=1;Path=/', port, newGuard));
            writeHead.call(bakRes, sts, headers);
          };
        }
      } catch (e) {
        // todo: factor out error report
        errmsg = e.toString();
        res.writeHead(400, {
          'Content-Length' : errmsg.length,
          'Content-Type' : 'text/plain'
        });
        res.end(errmsg);
        return false;
      }
    }

    // UA is not browser and not require session or browser not allow cookie
    if (ua.match(cfg.NoneBrowserPattern) || !fstReq) {
      tellOracle();
      return true;
    }

    function computeHost(){
      if (host) {
        host = host.split(':')[0];
        if (host.slice(-1).match(/\d/) || host.search(/\./) < 0) {
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
      ((follows && follows[0] !== 'head') ? (cLen ? writeToLength : writeToMarker) : process_header)(data);
    } catch (e) {
      // todo: release resources and write log
      if (next)
        next(e);
      else {
        console.error('\nPSP.WEB accept_oracle_data exception:');
        console.error(e);
        throw e;
      }
    }
  }

  function process_header(data){
    logger.turn('<- %d first respond', reqNo);
    var hLen = parseInt(data.slice(0, 5).toString('utf8'), 10);
    logger.oraResp("header length = " + data.slice(0, 5).toString('ascii'));
    var oraResHead = data.slice(5, 5 + hLen - 2).toString('utf8').split(CRLF);
    var bodyChunk = data.slice(5 + hLen, data.length);
    var status = oraResHead[0];
    if (follows) ohdr = {};
    for (var i = 1; i < oraResHead.length; i++) {
      var nv = oraResHead[i].split(": ");
      if (nv[0] === 'Set-Cookie') {
        if (ohdr[nv[0]]) ohdr['Set-Cookie'].push(nv[1]);
        else ohdr['Set-Cookie'] = [nv[1]];
      } else {
        ohdr[nv[0]] = nv[1];
      }
    }

    if (cLen = ohdr['Content-Length']) {
      cLen = parseInt(cLen);
    }
    var cLen2 = parseInt(ohdr['x-pw-ori-len']);
    delete ohdr['x-pw-ori-len'];

    if (follows) {
      follows.shift();
      if (fbId) {
        fbItem = fbBuffer[fbId] = new FBItem(status, ohdr);
      }
      if (cssmd5) {
        cssItem = cssBuffer[cssmd5] = new CSSItem(status, ohdr);
      }
      bodyChunk && accept_oracle_data(bodyChunk);
      return;
    }

    // cause feedback to follow in the same oraSock
    if (ohdr.Location && ohdr.Location.substr(0, 12) === 'feedback?id=') {
      fbId = ++curFeedbackSeq;
      ohdr.Location += fbId;
      res.writeHead(status, ohdr);
      follows = ['head', 'feedback'];
      bodyChunk.length && process_header(bodyChunk);
      return;
    }

    // cause css link to follow in the same oraSock
    if (cssmd5 = ohdr['x-css-md5']) {
      res.writeHead(status, ohdr);
      follows = ['main', 'head', 'css'];
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
      (ohdr['Content-Encoding'] === 'zip' || (ohdr['Content-Encoding'] === '?' && (cLen || cLen2) > cfg.zip_threshold))) {
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

    if (cLen === 0) {
      res.end();
      logger.oraResp('\n-- end response with zero content length --');
      fin();
      return;
    }

    if (!follows) {
      follows = ['main'];
    }

    if (bodyChunk.length) {
      logger.oraResp('first chunk has http header and parts of http body !');
      logger.oraResp('coupled http body size is %d', bodyChunk.length);
      if (cLen) {
        writeToLength(bodyChunk);
      } else {
        writeToMarker(bodyChunk);
      }
    }
  }

  function fin(){
    res.end();
    logger.turn('<= %d finished', reqNo);
    oraSock.removeAllListeners('data', accept_oracle_data);
    DBInMgr.pushBackToFreelist(oraSock, busyRec);
  }

  function writeToMarker(data){
    logger.oraResp('writeToMarker', data.length);
    var bLen = data.length;
    if (data.slice(bLen - endMark.length).toString('utf8') !== endMark) {
      res.write(data);
      md5Content && md5Content.write(data);
    } else {
      res.write(data.slice(0, bLen - endMark.length));
      md5Content && md5Content.end(data.slice(0, bLen - endMark.length));
      logger.oraResp('\n-- end response with marker --');
      fin();
    }
  }

  function writeToLength(data){
    if (bytesRead + data.length > cLen) {
      var extra = data.slice(cLen - bytesRead);
      data = data.slice(0, cLen - bytesRead);
    }
    logger.oraResp('writeToLength', data.length);
    bytesRead += data.length;
    logger.turn('<- %d received chunk %d/%d. cLen=%d', reqNo, data.length, bytesRead, cLen);

    switch (follows[0]) {
      case 'main':
        res.write(data);
        break;
      case 'feedback':
        fbItem.chunks.push(data);
        break;
      case 'css':
        cssItem.chunks.push(data);
        break;
      default:
        console.error('no such follow type as ' + follows[0]);
    }
    md5Content && md5Content.write(data);
    if (bytesRead === cLen) {
      bytesRead = 0;
      var sectType = follows.shift();
      if (follows.length === 0) {
        fin();
      }
    }

    if (extra) {
      if (follows.length > 0) {
        accept_oracle_data(extra);
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
}

module.exports = exports = function(req, res, next){
  try {
    pspdweb(req, res, next);
  } catch (e) {
    res.writeHead(200, {'Content-Type' : 'text/plain'});
    res.write('\nPSP.WEB middleware exception:');
    res.write(inspect(e));
    res.write('\n');
    res.end();
  }
};


