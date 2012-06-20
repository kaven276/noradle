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
  , reqCount = 0
  , errmsg
  , zip = require('./zip.js')
  , chooseZip = zip.chooseZip
  , zipMap = zip.zipMap
  , MD5Calc = require('./MD5Calc.js').Class
  , Cache = require('./Cache.js');
;

function pspdweb(req, res, next){
  var oraHeaderEnd = false
    , follow = false
    , endMark = '--the end--' + CRLF
    , oraSock
    , bytesRead = 0
    , cLen
    , fbseq
    , cssmd5
    , bakRes = res
    , compress
    , buffered_response = false
    , ohdr = {
      'x-powered-by' : cfg.server_name || 'Noradle - PSP.WEB'
    };

  reqCount++;
  logger.turn('No.%d request %s', reqCount, req.originUrl || req.url);

  // res.socket.setNoDelay();
  if (favicon(req, res)) return;

  var rb = new ReqBase(req);

  switch (rb.prog) {

    case 'feedback' :
      fbseq = parseInt(rb.search.split('=')[1]);
      oraSock = fbSocks[fbseq];
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
      cssmd5 = rb.path;
      oraSock = cssSocks[cssmd5].pop();
      if (oraSock) {
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
      DBInMgr.findFreeOraSockThen(function(c){
        if (c) {
          console.log(c.seq);
          oraSock = c;
          req_oracle(req, oraSock, rb, next);
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

  function accept_oracle_data(data){
    try {

      // console.log('received count = ' + (++rcv_cnt));
      if (oraHeaderEnd) {
        // console.log('\n-- received following oracle response data');
        if (cLen) {
          writeToLength(data);
        } else {
          writeToMarker(data);
        }
        return;
      }

      logger.turn('NO.%d first respond', reqCount);
      var hLen = parseInt(data.slice(0, 5).toString('utf8'), 10);
      // console.log("hLen=" + data.slice(0, 5).toString('utf8'));
      var oraResHead = data.slice(5, 5 + hLen - 2).toString('utf8').split(CRLF);
      // console.log(oraResHead);
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
        oraSock.removeListener('data', accept_oracle_data);
        fbSocks[curFeedbackSeq] = oraSock;
        return;
      }

      // cause css link to follow in the same oraSock
      if (css_md5 = ohdr['x-css-md5']) {
        follow = true;
        oraSock.removeListener('data', accept_oracle_data);
        if (cssSocks[css_md5]) {
          cssSocks[css_md5].push(oraSock);
        } else {
          cssSocks[css_md5] = [oraSock];
        }
      }

      // console.log('\n--- response headers ---');
      // console.log(ohdr);
      if (cLen = ohdr['Content-Length']) {
        cLen = parseInt(cLen);
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

      if (cLen === 0) {
        res.end();
        // console.log('\n-- end response with zero content length --');
        DBInMgr.pushBackToFreelist(oraSock);
        return;
      }

      if (bodyChunk.length) {
        // console.warn('\nfirst chunk has http header and parts of http body !');
        // console.warn('cupled http body size is %d', bodyChunk.length);
        if (cLen) {
          writeToLength(bodyChunk);
        } else {
          writeToMarker(bodyChunk);
        }
      }
    } catch (e) {
      // todo: release resources and write log
      if (next)
        next(e);
      else
        throw e;
    }
  }

  function writeToMarker(data){
    var bLen = data.length;
    if (data.slice(bLen - endMark.length).toString('utf8') !== endMark) {
      res.write(data);
    } else {
      res.end(data.slice(0, bLen - endMark.length));
      // console.log('\n-- end response with marker --');
      follow || DBInMgr.pushBackToFreelist(oraSock);
    }
  }

  function writeToLength(data){
    bytesRead += data.length;
    logger.turn('NO.%d received chunk %d/%d. cLen=%d', reqCount, data.length, bytesRead, cLen);
    if (bytesRead < cLen) {
      res.write(data);
    } else if (bytesRead === cLen) {
      res.end(data);
      // oraSock.pause();
      follow || DBInMgr.pushBackToFreelist(oraSock);
    } else {
      console.error(data.toString());
      DBInMgr.reportProtocolError(oraSock);
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


