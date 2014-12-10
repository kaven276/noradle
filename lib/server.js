var sysCfg = require('./cfg.js')
  , inspect = require('util').inspect
  , ReqBase = require('./ReqBase.js')
  , urlParse = require('url').parse
  , urlEncoded = require('./urlEncoded.js')
  , mergeHeaders = require('./util.js').mergeHeaders
  , merge = require('./util.js').merge
  , override = require('./util.js').override
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
  , monitor = require('./poolMonitor.js')
  , stat = {allCnt : 0, reqCnt : 0, cssCnt : 0, fbCnt : 0}
  , guidMgr = require('./guidMgr.js')
  , fmt = require('util').format
  , mGuard = require('./SidGuard.js')
  , sessionStore = require('./session.js')
  , urlParse = require('url').parse
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
  delete req.headers.cookie;
  return cookies;
}

module.exports = function(dbPool, ReqBaseC, customCfg){

  var cfg = override(sysCfg, customCfg || {});

  return function(req, res, next){
    try {
      pspdweb(req, res, next);
    } catch (e) {
      res.writeHead(500, {'Content-Type' : 'text/html'});
      res.write('PSP.WEB middleware exception:<pre>');
      res.write(inspect(e));
      res.end('</pre>');
    }
  };

  function pspdweb(req, res, next){
    var reqNo = ++stat.allCnt
      , reqUrl = req.originUrl || req.url
      , normalReq
      , cookies
      , oraSock /* todo: to be removed */
      , finCB /* too: to be removed */
      , rb
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
      , finished = false
      , ohdr = {
        'server' : 'nodejs',
        'x-powered-by' : 'Noradle - PSP.WEB'
      }
      , session
      ;

    logger.turn('-> %d %s', reqNo, reqUrl);

    if (urlParse(reqUrl).pathname === '/server-status') {
      monitor.showStatus(req, res, next);
      return;
    }

    // res.socket.setNoDelay();
    if (favicon(req, res)) return;

    cookies = req.cookies = parseCookie(req);
    rb = new (ReqBaseC || ReqBase)(req, res, next);
    rb.done || merge(rb, new ReqBase(req, res, next));
    delete rb.done;

    switch (rb.x$prog) {

      case 'feedback' :
        stat.fbCnt++;
        var fbseq = parseInt(rb.u$qstr.split('=')[1]);
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
        return;

      case 'css' :
        stat.cssCnt++;
        cssmd5 = rb.u$spath;
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
          res.writeHead(400, {'x-no-css' : 'no-css-item'});
          res.end('please donnot refresh the css manually!');
        }
        return;
    }

    stat.reqCnt++;
    normalReq = true;
    if (ensureSID() === false) {
      return;
    }

    req.on('close', function(){
      if (!finished) {
        console.log(req.url, 'req.onClose', 'client aborted', req.socket.readable, req.socket.writable, req.socket == res.socket);
        // todo: need to signal later queue to abort
        interrupter.abort();
      }
    });

    if (false) {
      req.socket.on('end', function(){
        if (!finished) {
          console.log(req.url, 'req.socket.onEnd', 'client aborted', req.socket.readable, req.socket.writable);
        }
      });

      req.socket.on('error', function(err){
        if (!finished) {
          console.log(req.url, 'req.socket.onError', 'client aborted', err, req.socket.readable, req.socket.writable);
        }
      });

      req.socket.on('close', function(had_error){
        if (!finished) {
          console.log(req.url, 'req.socket.onClose', 'client aborted', had_error, req.socket.readable, req.socket.writable);
        }
      });
    }

    var interrupter = dbPool.findFree(reqUrl, null, function(err, oraReq){
      if (err) {
        onNoFreeConnection(err);
        return;
      }
      oraReq.once('response_timeout', onResponseTimeout);
      oraReq.once('socket_released', onSocketReleased);
      oraReq.init('HTTP', rb.y$hprof || '');

      // 1. http request headers, pass throuth to oracle except for cookies
      if ("h$" in rb) {
        // already set in preprocessor, after discarding/spliting some headers
        delete rb.h$;
      } else {
        // add as real http headers send to node
        oraReq.addHeaders(req.headers, 'h$');
      }

      // 2. http request header's cookies
      if ("c$" in rb) {
        // already set in preprocessor, after discarding/spliting some headers
        delete rb.c$;
      } else {
        // add as real http header cookies send to node
        oraReq.addHeaders(cookies, 'c$');
      }

      // 3.basic http request key-values
      var parts = rb.x$prog.split('.');
      if (parts.length === 1) {
        rb.x$pack = '';
        rb.x$proc = parts[0];
      } else {
        rb.x$pack = parts[0];
        rb.x$proc = parts[1];
      }
      oraReq.addHeaders(rb, '');

      // 4. parameters, for method=get from querystring, for method=post from body
      oraReq.addHeaders(urlEncoded(urlParse(req.url).query), '');

      // 5. session data
      // todo need app, bsid, encoding
      if (rb.x$app && rb.c$BSID && (session = sessionStore.gets(rb.x$app, rb.c$BSID))) {
        session.store.IDLE = (Date.now() - session.LAT);
        session.LAT = Date.now();
        oraReq.addHeaders(session.store, 's$');
      }

      if (req.method === 'POST') {
        var req_mime = req.headers['content-type'].split(';')[0];
        switch (req_mime) {
          case  'application/x-www-form-urlencoded' :
            req.setEncoding('utf8');
            var bdy = '';
            req.on('data', function(chunk){
              bdy += chunk;
            });
            req.on('end', function(){
              oraReq.addHeaders(urlEncoded(bdy), '');
              oraReq.end(cb);
            });
            break;
          case 'multipart/form-data' :
            oraReq.end(cb);
            upload(req, oraSock, next);// todo:
            break;
          default:
            req.on('data', function(chunk){
              // sent http request body to oracle if oracle can accept
              oraReq.write(chunk);
            });
            req.on('end', function(){
              // signal final of request body or leave it to content-length
              oraReq.end(cb);
            });
        }
      } else {
        // http get
        oraReq.end(cb);
        req.on('close', function(){
          console.log('client req close');
        });
      }

      function fin(){
        if (oraReq.follows.length === 0) {
          res.end();
          finished = true;
        }
      }

      function cb(oraRes){
        // maybe first response, maybe following response
        var status = oraRes.status
          , cLen = ohdr['Content-Length']
          , headers = oraRes.headers
          ;
        if (cLen) {
          cLen = parseInt(cLen);
        }

        if ('s$BSID' in headers) {
          if (headers.s$BSID) {
            // if oracle servlet create new session with unique BSID
            session = sessionStore.create(rb.x$app, headers.s$BSID);
          } else {
            // if oracle servlet want to destroy session store
            session = sessionStore.destroy(rb.x$app, rb.c$BSID);
          }
          delete headers.s$BSID;
        }
        // move session setting data to session store
        if (session) {
          for (n in headers) {
            if (n.substr(0, 2) == 's$') {
              session.set([n.substr(2)], headers[n]);
              delete headers[n];
            }
          }
        }

        // todo: cookies conflict need coverage test

        if (oraReq.follows.length === 0) {
          mergeHeaders(ohdr, headers);
        } else {
          oraReq.follows.shift();
          ohdr = {};
          mergeHeaders(ohdr, headers);
          oraRes.on('end', function(){
            fin();
          });
          if (fbId) {
            fbItem = fbBuffer[fbId] = new FBItem(status, ohdr);
            oraRes.on('data', function(data){
              fbItem.chunks.push(data);
            });
          }
          if (cssmd5) {
            cssItem = cssBuffer[cssmd5] = new CSSItem(status, ohdr);
            oraRes.on('data', function(data){
              cssItem.chunks.push(data);
            });
          }
          return;
        }

        oraRes.on('data', function(data){
          res.write(data);
          md5Content && md5Content.write(data);
        });

        oraRes.on('end', function(){
          if (md5Content) {
            md5Content.end();
            md5Content = null;
          }
          fin();
        });

        // cause feedback to follow in the same oraSock
        if (ohdr.Location && ohdr.Location.substr(0, 12) === 'feedback?id=') {
          fbId = ++curFeedbackSeq;
          ohdr.Location += fbId;
          res.writeHead(status, ohdr);
          oraReq.follows = ['feedback'];
          return;
        }

        // cause css link to follow in the same oraSock
        if (cssmd5 = ohdr['x-css-md5']) {
          res.writeHead(status, ohdr);
          oraReq.follows = ['css'];
        }

        // todo: cache will be redesigned
        if (normalReq && cfg.use_gw_cache && ohdr['ETag'] && status != 304) {
          md5val = ohdr['ETag'].substr(1, 24);
          if (cachedEntity = Cache.findCacheHit(req.url, md5val)) {
            oraSock.write('Cache Hit' + CRLF);
            cachedEntity.respond(req, res);
            finCB(null);
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
          (ohdr['Content-Encoding'] === 'zip' || (ohdr['Content-Encoding'] === '?' && cLen > cfg.zip_threshold))) {
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
          fin();
        }
      }
    });

    function ensureSID(){
      var host = req.headers.host
        , port = rb.u$port
        , fstReq = (res.socket._bytesDispatched === 0)
        , msid = cookies['MSID']
        , bsid = cookies['BSID']
        , guard = cookies['GUARD' + port]
        , newGuard
        , ua = req.headers['user-agent'] || ''
      //, uaHash = utl.hash2(ua)
        , setCookies = []
        , writeHead
        ;

      delete cookies['GUARD' + port];
      ohdr['Set-Cookie'] = setCookies;

      if (bsid && cfg.check_session_hijack) {
        try {
          if (newGuard = mGuard.checkUpdate(host, bsid, guard, rb.a$caddr)) {
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
          return [addr.address, addr.port].join(':');
        }
      }

      function tellOracle(){
        (rb.c$BSID === undefined) && (rb.c$BSID = bsid || '');
        rb.c$MSID = msid || '';
        //rb.a$uaHash = uaHash || '';
      }

      if (!msid || !bsid) {
        computeHost();
        if (!msid) {
          msid = guidMgr.create();
          // var tEnd = new Date(Date.UTC(9999, 1, 1, 0, 0, 0, 0)).toGMTString();
          setCookies.push(fmt('MSID=%s%s;Version=1;Max-Age=%s;Path=/', msid, host ? (';Domain=.' + host) : '', 10000 * 24 * 60 * 60));
        }
        if (!bsid) {
          bsid = guidMgr.create(getStripe());
          setCookies.push(fmt('BSID=%s%s;Version=1;Path=/', bsid, host ? (';Domain=.' + host) : ''));
        }
      }

      tellOracle();
    }

    function onResponseTimeout(interval){
      errmsg = 'execute over ' + interval + ' milliseconds and nothing response received!';
      res.writeHead(504, 'Gateway Timeout', {
        'Content-Length' : errmsg.length,
        'Content-Type' : 'text/plain',
        'Retry-After' : '3'
      });
      res.end(errmsg);
    }

    function onSocketReleased(interval){
      errmsg = 'execute over ' + interval + ' milliseconds and busy socket released!';
      res.writeHead(500, 'Internal Server Error', {
        'Content-Length' : errmsg.length,
        'Content-Type' : 'text/plain',
        'Retry-After' : '3'
      });
      res.end(errmsg);
    }

    function onNoFreeConnection(err){
      // console.log('no database server connection/process available');
      errmsg = 'waiting for free database connection timeout';
      res.writeHead(503, 'Service Unavailable', {
        'Content-Length' : errmsg.length,
        'Content-Type' : 'text/plain',
        'Retry-After' : '3'
      });
      res.end(errmsg);
    }

  }
}
;


