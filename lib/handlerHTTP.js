"use strict";
var sysCfg = require('./cfg.js')
  , inspect = require('util').inspect
  , ReqBase = require('./ReqBase.js')
  , urlParse = require('url').parse
  , urlEncoded = require('./util/urlEncoded.js')
  , jsonParse = require('./util/jsonParse.js')
  , parseCookie = require('./util/util.js').parseCookie
  , nvStripTag = require('./util/util.js').nvStripTag
  , defaultErrorPage = require('./util/util.js').defaultErrorPage
  , mergeAdd = require('./util/util.js').mergeAdd
  , override = require('./util/util.js').override
  , debug = require('debug')('noradle:servlet')
  , debugReq = require('debug')('noradle:reqSocket')
  , Feedback = require('./middleware/Feedback.js')
  , CSS = require('./middleware/CSS.js')
  , GatewayCache = require('./middleware/GatewayCache.js')
  , zip = require('./middleware/zip.js')
  , MD5CalcFilter = require('./middleware/MD5Calc.js')
  , ResultSetsFilter = require('./middleware/ResultSetsFilter.js')
  , ConverterFilter = require('./middleware/Converter.js')
  , stat = {allCnt : 0, reqCnt : 0, cssCnt : 0, fbCnt : 0}
  , sessionStore = require('./session.js')
  , error_pages = require('./error_pages.js')
  , ensureSid = require('./middleware/SessionGuard/ensureSID.js')
  , specialURLHandler = require('./specialURL.js').handler
  ;

module.exports = function(dbPool, ReqBaseC, customCfg){

  if (arguments.length === 2 && typeof ReqBaseC === 'object') {
    customCfg = ReqBaseC;
    ReqBaseC = null;
  }

  var cfg = override(sysCfg, customCfg || {})
    , upload = require('./middleware/upload.js')(cfg)
    , cssFilter = CSS.filter(cfg)
    , feedbackFilter = Feedback.filter(cfg)
    , resultSetsFilter = ResultSetsFilter(cfg)
    , converterFilter = ConverterFilter(cfg)
    , zipFilter = zip.zipFilter(cfg)
    , md5CalcFilter = MD5CalcFilter(cfg)
    , gatewayCacheFilter
    ;

  if (cfg.GatewayCache == true) {
    cfg.GatewayCache = {};
    gatewayCacheFilter = GatewayCache.filter(cfg);
  } else if (cfg.GatewayCache.filter) {
    gatewayCacheFilter = cfg.GatewayCache.filter(cfg);
  } else {
    gatewayCacheFilter = GatewayCache.filter(cfg);
  }

  return function httpGatewayHandler(req, res, next){
    next = next || defaultErrorPage;
    var reqNo = ++stat.allCnt
      , reqUrl = req.originUrl || req.url
      , cookies
      , rb
      , finished = false
      , session
      , sTime = Date.now()
      ;

    debug('-> %d %s', reqNo, reqUrl);

    res.setHeader('server', 'nodejs');
    res.setHeader('x-powered-by', 'Noradle - PSP.WEB');
    res.on('finish', function(){
      finished = true;
    });

    if (specialURLHandler(req, res, next, cfg)) return;

    cookies = req.cookies = parseCookie(req);

    // give oracle request headers
    rb = new (ReqBaseC || ReqBase)(req, cfg);
    rb.done || mergeAdd(rb, new ReqBase(req, cfg));
    delete rb.done;
    if (rb.x$bypass) {
      next();
      return;
    }
    if (rb.u$location) {
      res.writeHead(302, {'Location' : rb.u$location});
      res.end();
      return;
    }
    if (cfg.adjust_env_func) {
      cfg.adjust_env_func(rb, req, cfg);
    }

    switch (rb.x$prog) {

      case 'feedback_b' :
        stat.fbCnt++;
        Feedback.use(res, req, parseInt(rb.u$qstr.split('=')[1]));
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
    if (ensureSid(req, res, res, rb, cfg) === false) {
      return;
    }

    req.on('close', function(){
      if (!finished) {
        debugReq(req.url, 'req.onClose', 'client aborted', req.socket.readable, req.socket.writable, req.socket == res.socket);
        // todo: need to signal later queue to abort
        // interrupter.abort();
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

    /* todo: compute y$uri, search LAT/LSCN/MD5 in cache with the same y$uri as key
     if have, send y$lmdt, y$lscn, y$md5 in rb
     or if cache is not expire, check session right and use it directly
     do send request to db
     */

    (function(){

      var postHeaders, postChunks = [];

      if (gatewayCacheFilter && GatewayCache) {
        var oraRes = gatewayCacheFilter.before(req, rb);
        oraRes ? onResponse(oraRes) : dealPost();
      } else {
        dealPost();
      }

      function sendAll(){
        var interrupter = dbPool.findFree(reqUrl, null, function(err, oraReq){
          if (err) {
            (error_pages.onNoFreeConnection(res))(err);
            return;
          }

          oraReq.once('response_timeout', error_pages.onResponseTimeout(res));
          oraReq.once('socket_released', error_pages.onSocketReleased(res));
          setRequestHeaders(oraReq);
          if (cfg.strip_tag) {
            postHeaders = nvStripTag(postHeaders);
          }
          postHeaders && oraReq.addHeaders(postHeaders);
          oraReq._sendHeaders();
          for (var i = 0, len = postChunks.length; i < len; i++) {
            oraReq.write(postChunks[i]);
          }
          oraReq.end(onResponse);
          rb.t$ && res.setHeader('x-pw-ntime-1-sent', Date.now() - sTime);
        });
      }

      function setRequestHeaders(oraReq){
        oraReq.init('HTTP', rb.y$hprof || '');

        // 1. http request headers, pass throuth to oracle except for cookies
        if (!rb.h$) {
          // already set in preprocessor, after discarding/spliting some headers
        } else {
          // add as real http headers send to node
          oraReq.addHeaders(req.headers, 'h$');
          delete rb.h$;
        }

        // 2. http request header's cookies
        if (!rb.c$) {
          // already set in preprocessor, after discarding/spliting some headers
        } else {
          // add as real http header cookies send to node
          oraReq.addHeaders(cookies, 'c$');
          delete rb.c$;
        }

        // 3.basic http request key-values
        oraReq.addHeaders(rb, '');

        // 4. parameters, for method=get from querystring, for method=post from body
        if (cfg.strip_tag) {
          oraReq.addHeaders(nvStripTag(urlEncoded(urlParse(req.url).query)));
        } else {
          oraReq.addHeaders(urlEncoded(urlParse(req.url).query));
        }


        // 5. session data
        // todo need app, bsid, encoding
        if (rb.s$ && rb.c$BSID && (session = sessionStore.gets(rb.s$, rb.c$BSID))) {
          session.store.IDLE = (Date.now() - session.LAT);
          session.LAT = Date.now();
          oraReq.addHeaders(session.store, 's$');
        }
      }

      function dealPost(){

        if (req.method === 'POST') {
          var cLen = req.headers['content-length'];
          if (cLen && parseInt(cLen) === 0) {
            return;
          }
          var req_mime = (req.headers['content-type'] || '').split(';')[0];
          if (req.headers.post_json) {
            req_mime = 'default';
          }
          //todo: onData -> onReadable
          switch (req_mime) {
            case  'application/x-www-form-urlencoded' :
              req.setEncoding('ascii');
              (function(){
                var bdy = '';
                req.on('data', function(chunk){
                  bdy += chunk;
                });
                req.on('end', function(){
                  postHeaders = urlEncoded(bdy);
                  sendAll();
                });
              })();
              break;
            case  'application/json' :
              //todo: use direct post as default is ok, unless client say he want json as name-value pairs
              req.setEncoding('utf8');
              (function(){
                var bdy = '';
                req.on('data', function(chunk){
                  bdy += chunk;
                });
                req.on('end', function(){
                  postHeaders = jsonParse(bdy);
                  sendAll();
                });
              })();
              break;
            case 'multipart/form-data' :
              upload(req, postHeaders = {}, sendAll, next);
              break;
            default:
              if ('y$instream' in rb) {
                oraReq.end(onResponse);
                postChunks = [];
                req.on('data', function(chunk){
                  postChunks.push(chunk);
                });
              } else {
                (function(){
                  var cLen = 0;
                  req.on('data', function(chunk){
                    postChunks.push(chunk);
                    cLen += chunk.length;
                  });
                  req.on('end', function(){
                    postHeaders = {'h$content-length' : cLen.toString()};
                    sendAll();
                  });
                })();
              }
          }
        } else {
          // other than post, is http get
          req.on('data', function(data){
            // to allow event end to occur
          });
          req.on('end', function(){
            sendAll();
          });
        }
      }

      function onResponse(oraRes){
        rb.t$ && res.setHeader('x-pw-ntime-2-got-head', Date.now() - sTime);

        if (gatewayCacheFilter) {
          oraRes = gatewayCacheFilter.after(oraRes, res, req, rb);
        }

        // copy response status/headers from oraRes to http res
        res.statusCode = oraRes.status;
        for (var n in oraRes.headers) {
          res.setHeader(n, oraRes.headers[n]);
        }

        /**
         * only this headers will output by oracle
         * 1. Content-Type (default to text/html;charset=utf-8)
         * 2. Content-Length (may none for flushed body)
         * 3. Location (when do redirect, h.gol ...)
         * todo: cookies conflict need coverage test
         * after this, all filter can only add/modify/delete res properties
         */
        ;

        // step 0: update session
        // todo: use a type=4 frame to set session data
        oraRes.on('session', function(delta){
          if ('s$BSID' in delta) {
            if (delta.s$BSID) {
              // if oracle servlet create new session with unique BSID
              session = sessionStore.create(rb.s$, delta.s$BSID);
            } else {
              // if oracle servlet want to destroy session store
              session = sessionStore.destroy(rb.s$, rb.c$BSID);
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
        var headers = oraRes.headers;
        oraRes = cssFilter(oraRes);

        // step 2: prevent browser from re-submit the same transaction
        if (feedbackFilter(oraRes, res, req, headers)) {
          return;
        }

        // step 4: content converters
        oraRes = resultSetsFilter(oraRes, res, req, rb, next);
        if (!oraRes) return;

        oraRes = converterFilter(oraRes, res);

        // step 5: zip transfer
        oraRes = zipFilter(oraRes, res, req);

        // step 6: content-md5 compute
        oraRes = md5CalcFilter(oraRes, res);

        oraRes.on('data', function(data){
          rb.t$ && (res.headersSent || res.setHeader('x-pw-ntime-3-write-head', Date.now() - sTime));
          res.write(data);
        });

        oraRes.on('end', function(){
          rb.t$ && (res.headersSent || res.setHeader('x-pw-ntime-3-write-head', Date.now() - sTime));
          res.end();
        });
      }
    })();
  }
};
