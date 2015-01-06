var sysCfg = require('./cfg.js')
  , inspect = require('util').inspect
  , ReqBase = require('./ReqBase.js')
  , urlParse = require('url').parse
  , urlEncoded = require('./util/urlEncoded.js')
  , mergeHeaders = require('./util/util.js').mergeHeaders
  , mergeAdd = require('./util/util.js').mergeAdd
  , override = require('./util/util.js').override
  , logger = require('./logger.js')
  , CRLF = '\r\n'
  , curFeedbackSeq = 0
  , fbBuffer = {}
  , cssBuffer = {}
  , upload = require('./middleware/upload.js')
  , zip = require('./middleware/zip.js')
  , chooseZip = zip.chooseZip
  , zipFilter = zip.zipFilter
  , MD5CalcFilter = require('./middleware/MD5Calc.js')
  , ResultSetsFilter = require('./middleware/ResultSetsFilter.js')
  , Cache = require('./middleware/Cache.js')
  , monitor = require('./poolMonitor.js')
  , stat = {allCnt : 0, reqCnt : 0, cssCnt : 0, fbCnt : 0}
  , sessionStore = require('./session.js')
  , error_pages = require('./error_pages.js')
  , ensureSid = require('./middleware/SessionGuard/ensureSID.js')
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

    if (urlParse(reqUrl).pathname === cfg.status_url) {
      monitor.showStatus(req, res, next);
      return;
    }

    // res.socket.setNoDelay();
    // todo: to be removed from NGW of PLSQL servlet
    if (reqUrl === '/favicon.ico') {
      if (cfg.favicon_url) {
        res.writeHead(302, {'Location' : cfg.favicon_url});
        res.end();
      } else {
        next();
      }
      return;
    }

    cookies = req.cookies = parseCookie(req);

    // give oracle request headers
    rb = new (ReqBaseC || ReqBase)(req, res, next);
    rb.done || mergeAdd(rb, new ReqBase(req, res, next));
    delete rb.done;

    function sendResponse(item){
      res.writeHead(item.status, item.headers);
      item.chunks.forEach(function(chunk){
        res.write(chunk);
      });
      res.end();
    }

    switch (rb.x$prog) {

      case 'feedback_b' :
        if (rb.u$spath) {
          next();
          return;
        }
        stat.fbCnt++;
        fbId = parseInt(rb.u$qstr.split('=')[1]);
        fbItem = fbBuffer[fbId];
        if (fbItem) {
          delete fbBuffer[fbId];
          sendResponse(fbItem);
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

      case 'css_b' :
        if (rb.u$spath.search(/\./) >= 0) {
          next();
          return;
        }
        stat.cssCnt++;
        cssmd5 = rb.u$spath;
        cssItem = cssBuffer[cssmd5];
        if (cssItem) {
          // todo: need to lookup the oraSock status, if it's really free at the moment, or timeout by monitor
          delete cssBuffer[cssmd5];
          sendResponse(cssItem);
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

      default:
        // allow static file with same url prefix with plsql servlet
        if (rb.x$dbu.search(/\./) >= 0 || !rb.x$prog.match(/^\w+_\w(\.\w+)?$/)) {
          next();
          return;
        }
    }

    stat.reqCnt++;
    normalReq = true;
    if (ensureSid(req, res, bakRes, rb, ohdr, cfg) === false) {
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
        (error_pages.onNoFreeConnection(res))(err);
        return;
      }
      oraReq.once('response_timeout', error_pages.onResponseTimeout(res));
      oraReq.once('socket_released', error_pages.onSocketReleased(res));
      sendRequest();

      function sendRequest(){
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
              req.setEncoding('ascii');
              (function(){
                var bdy = '';
                req.on('data', function(chunk){
                  bdy += chunk;
                });
                req.on('end', function(){
                  oraReq.addHeaders(urlEncoded(bdy), '');
                  oraReq.end(onResponse);
                });
              })();
              break;
            case 'multipart/form-data' :
              oraReq.end(onResponse);
              upload(req, oraSock, next);// todo:
              break;
            default:
              if ('y$instream' in rb) {
                oraReq.end(onResponse);
                req.on('data', function(chunk){
                  oraReq.write(chunk);
                });
                // todo: how to mark end of request body
              } else if ('content-length' in req.headers) {
                if ('h$content-length' in rb) ; else {
                  oraReq.addHeader('h$content-length', req.headers['content-length']);
                }
                oraReq.end(onResponse);
                req.on('data', function(chunk){
                  oraReq.write(chunk);
                });
              } else {
                (function(){
                  var chunks = [], cLen = 0;
                  req.on('data', function(chunk){
                    chunks.push(chunk);
                    cLen += chunk.length;
                  });
                  req.on('end', function(){
                    oraReq.addHeader('h$content-length', cLen.toString());
                    oraReq.end(onResponse);
                    for (var i = 0, len = chunks.length; i < len; i++) {
                      oraReq.write(chunks[i]);
                    }
                  });
                })();
              }
          }
        } else {
          // http get
          oraReq.end(onResponse);
        }

        req.on('close', function(){
          console.log('client req close', reqUrl);
        });
      }

      var step = 1;

      function onResponse(oraRes){
        // maybe first response, maybe following response
        var status = oraRes.status
          , headers = oraRes.headers
          , cLen = parseInt(headers['Content-Length'])
          , flags = {headFixed : true}
          ;

        if (oraReq.follows.length > 0) {
          oraReq.follows.shift();
          step--;
          oraRes.on('end', function(){
            fin();
          });
          if (fbId) {
            headers['ETag'] = '"' + fbId + '"';
            headers['Cache-Control'] = 'max-age=600';
            fbItem = fbBuffer[fbId] = new FBItem(status, headers);
            oraRes.on('data', function(data){
              fbItem.chunks.push(data);
            });
          }
          if (cssmd5) {
            headers['ETag'] = '"' + cssmd5 + '"';
            headers['Cache-Control'] = 'max-age=60000';
            cssItem = cssBuffer[cssmd5] = new CSSItem(status, headers);
            oraRes.on('data', function(data){
              cssItem.chunks.push(data);
            });
          }
          return;
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
        mergeHeaders(ohdr, headers);

        // cause feedback to follow in the same oraSock
        if (ohdr.Location && ohdr.Location === 'feedback_b?id=') {
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
          step++; // -- on oraRes.end
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

        oraRes = ResultSetsFilter(oraRes, ohdr, flags);

        if ((compress = chooseZip(req)) && false &&
          (ohdr['Content-Encoding'] === 'zip' || (ohdr['Content-Encoding'] === '?' && cLen > cfg.zip_threshold))) {
          oraRes = zipFilter(oraRes, ohdr, flags, {method : compress});
        } else {
          delete ohdr['Content-Encoding'];
        }

        oraRes = MD5CalcFilter(oraRes, ohdr, flags);
        flags.headFixed && bakRes.writeHead(status, ohdr);

        if (cLen === 0) {
          fin();
        }

        oraRes.on('data', function(data){
          res.write(data);
          md5Content && md5Content.write(data);
        });

        oraRes.on('end', function(chunks){
          if (!flags.headFixed) {
            bakRes.writeHead(status, ohdr);
          }
          if (chunks) {
            chunks.forEach(function(chunk){
              oraRes.emit('data', chunk);
            });
          }
          if (md5Content) {
            md5Content.end();
            md5Content = null;
          }
          step--;
          fin();
        });
      }

      function fin(){
        if (step === 0) {
          res.end();
          finished = true;
        }
      }

    });

  }
};


