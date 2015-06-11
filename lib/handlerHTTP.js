var sysCfg = require('./cfg.js')
  , inspect = require('util').inspect
  , ReqBase = require('./ReqBase.js')
  , urlParse = require('url').parse
  , urlEncoded = require('./util/urlEncoded.js')
  , jsonParse = require('./util/jsonParse.js')
  , mergeHeaders = require('./util/util.js').mergeHeaders
  , mergeAdd = require('./util/util.js').mergeAdd
  , override = require('./util/util.js').override
  , noop = require('./util/util.js').override
  , debug = require('debug')('noradle:servlet')
  , debugReq = require('debug')('noradle:reqSocket')
  , CRLF = '\r\n'
  , Feedback = require('./middleware/Feedback.js')
  , CSS = require('./middleware/CSS.js')
  , zip = require('./middleware/zip.js')
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

  var cfg = override(sysCfg, customCfg || {})
    , upload = require('./middleware/upload.js')(cfg)
    ;

  return function(req, res, next){
    next = next || noop;
    pspdweb(req, res, next);
    return;
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
      , compress
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

    debug('-> %d %s', reqNo, reqUrl);

    if (urlParse(reqUrl).pathname === cfg.status_url) {
      monitor.showStatus(req, res, next);
      return;
    }

    // res.socket.setNoDelay();
    // todo: to be removed from NGW of PLSQL servlet
    if (reqUrl === '/favicon.ico') {
      if (cfg.favicon_url) {
        res.writeHead(301, {'Location' : cfg.favicon_url});
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

    switch (rb.x$prog) {

      case 'feedback_b' :
        stat.fbCnt++;
        Feedback.use(res, parseInt(rb.u$qstr.split('=')[1]));
        return;

      case 'css_b' :
        if (rb.u$spath.search(/\./) >= 0) {
          next();
          return;
        }
        stat.cssCnt++;
        CSS.use(res, rb.u$spath);
        return;

      default:
        // allow static file with same url prefix with plsql servlet
        if (!rb.x$dbu || !rb.x$prog || rb.x$dbu.search(/\./) >= 0 || !rb.x$prog.match(/^\w+_\w(\.\w+)?$/)) {
          next();
          return;
        }
    }

    stat.reqCnt++;
    normalReq = true;
    if (ensureSid(req, res, res, rb, ohdr, cfg) === false) {
      return;
    }

    req.on('close', function(){
      if (!finished) {
        debugReq(req.url, 'req.onClose', 'client aborted', req.socket.readable, req.socket.writable, req.socket == res.socket);
        // todo: need to signal later queue to abort
        interrupter.abort();
      }
    });

    if (false) {
      req.socket.on('end', function(){
        if (!finished) {
          debugReq(req.url, 'req.socket.onEnd', 'client aborted', req.socket.readable, req.socket.writable);
        }
      });

      req.socket.on('error', function(err){
        if (!finished) {
          debugReq(req.url, 'req.socket.onError', 'client aborted', err, req.socket.readable, req.socket.writable);
        }
      });

      req.socket.on('close', function(had_error){
        if (!finished) {
          debugReq(req.url, 'req.socket.onClose', 'client aborted', had_error, req.socket.readable, req.socket.writable);
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
          var cLen = req.headers['content-length'];
          if (cLen && parseInt(cLen) === 0) {
            oraReq.end(onResponse);
            return;
          }
          var req_mime = (req.headers['content-type'] || '').split(';')[0];
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
            case  'application/json' :
              req.setEncoding('utf8');
              (function(){
                var bdy = '';
                req.on('data', function(chunk){
                  bdy += chunk;
                });
                req.on('end', function(){
                  oraReq.addHeaders(jsonParse(bdy), '');
                  console.log('oraReq._buf', oraReq._buf);
                  oraReq.end(onResponse);
                });
              })();
              break;
            case 'multipart/form-data' :
              upload(req, oraReq, onResponse, next);// todo:
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
          debugReq('client req close', reqUrl);
        });
      }

      function onResponse(oraRes){
        // maybe first response, maybe following response
        var status = oraRes.status
          , headers = oraRes.headers
          , cLen = parseInt(headers['Content-Length'])
          , flags = {headFixed : true}
          , type = (rb.x$pack || rb.x$proc).substr(-1)
          ;

        // step 0: update session
        // todo: use a type=4 frame to set session data
        oraRes.on('session', function(delta){
          if ('s$BSID' in delta) {
            if (delta.s$BSID) {
              // if oracle servlet create new session with unique BSID
              session = sessionStore.create(rb.x$app, delta.s$BSID);
            } else {
              // if oracle servlet want to destroy session store
              session = sessionStore.destroy(rb.x$app, rb.c$BSID);
            }
            delete delta.s$BSID;
          }
          // move session setting data to session store
          if (session) {
            for (n in delta) {
              if (n.substr(0, 2) == 's$') {
                session.set([n.substr(2)], delta[n]);
              }
            }
          }
        });


        // step 1: css handler, before feedback
        // so feedback print can use embed/linked css as normal page
        // cause css link to follow in the same oraSock
        oraRes = CSS.filter(oraRes);

        // step 2: prevent browser from re-submit the same transaction
        // only no error write will automatically do redirect url
        // note: error response means rollback, will not cause repeated write
        debug('type=%s, status=%d, cLen=%d', type, status, cLen);
        if (type === 'c' && status === 200 && !req.headers['x-requested-with']) {
          if (cLen === 0) {
            var referer = req.headers['referer'];
            if ('referer' in req.headers) {
              ohdr['Location'] = req.headers['referer'];
              res.writeHead(303, ohdr);
              res.end();
              finished = true;
            } else {
              ohdr['Content-Type'] = 'text/html';
              res.writeHead(200, ohdr);
              res.end('<script>history.back();</script>');
              finished = true;
            }
            debug('call _c return back!');
          } else if (headers['Content-Type'].match(/^text\/html;/)) {
            // may streamed or not
            Feedback.store(oraRes, ohdr, function onEnd(){
              res.writeHead(303, ohdr);
              res.end();
              finished = true;
            });
          }
          return;
        }

        // todo: cookies conflict need coverage test
        mergeHeaders(ohdr, headers);

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
        // step 5: zip transfer
        flags.acceptEncoding = req.headers['accept-encoding'];
        flags.zip_threshold = cfg.zip_threshold;
        oraRes = zipFilter(oraRes, ohdr, flags, res);


        oraRes = MD5CalcFilter(oraRes, ohdr, flags);
        flags.headFixed && res.writeHead(status, ohdr);

        if (cLen === 0) {
          fin();
        }

        oraRes.on('data', function(data){
          res.write(data);
          md5Content && md5Content.write(data);
        });

        oraRes.on('end', function(chunks){
          if (!flags.headFixed) {
            res.writeHead(status, ohdr);
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
          fin();
        });
      }

      function fin(){
        res.end();
        finished = true;
      }

    });

  }
}
;


