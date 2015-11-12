"use strict";
var EE = require('events').EventEmitter
  , debug = require('debug')('noradle:zip')
  , zlib = require('zlib')
  , zipMap = exports.zipMap = {
    'gzip' : zlib.createGzip,
    'deflate' : zlib.createDeflateRaw
  };

function chooseZip(acceptEncoding){
  // from the NodeJS available methods, choose the client supported method with the highest priority
  var v_zips = acceptEncoding || '';
  if (~v_zips.indexOf('gzip')) {
    return 'gzip';
  }
  if (~v_zips.indexOf('deflate')) {
    return 'deflate';
  }
}

// must be the last filter
exports.zipFilter = function(cfg){
  return function(oraRes, res, req){
    var ee = new EE()
      , method = chooseZip(req.headers['accept-encoding'])
      ;

    function cacheHead(method, thres){
      debug('cacheHead method=%s, thres=%d', method, thres);
      var compress
        , aLen = 0
        , headBuf = []
        , over = false
        ;

      function doZip(){
        debug('doZip');
        res.setHeader('Content-Encoding', method);
        res.setHeader('Transfer-Encoding', 'chunked');
        if (res.getHeader('Content-Length')) {
          res.setHeader('x-pw-content-length', res.getHeader('Content-Length'));
          res.removeHeader('Content-Length');
        }
        debug('doZip write head status=%j', oraRes);

        compress = zipMap[method]();
        headBuf.forEach(function(chunk){
          compress.write(chunk);
        });
        compress.on('data', function(data){
          ee.emit('data', data);
        });
        compress.on('end', function(){
          ee.emit('end');
        });
      }

      /*
       under over, cache data
       when over, write cached data to zip, then trap zip.onData to ee.emit
       when finally not over, then ee.emit original data
       */

      oraRes.on('data', function(data){
        if (over) {
          compress.write(data);
        } else {
          headBuf.push(data);
          aLen += data.length;
          if (aLen > thres) {
            over = true;
            doZip();
          }
        }
      });

      oraRes.on('end', function(){
        if (over) {
          compress.end();
        } else {
          res.removeHeader('Content-Encoding');
          if (!res.getHeader('Content-Length')) {
            res.setHeader('Content-Length', aLen.toString());
            res.removeHeader('Transfer-Encoding');
          }
          for (var i = 0, len = headBuf.length; i < len; i++) {
            ee.emit('data', headBuf[i]);
          }
          ee.emit('end');
        }
      });
    }

    if (!method) {
      res.removeHeader('Content-Encoding');
      return oraRes;
    } else if (res.getHeader('Content-Encoding') === 'zip') {
      cacheHead(method, 0);
      return ee;
    } else if (res.getHeader('Content-Encoding') === '?') {
      cacheHead(method, cfg.zip_threshold || 1000);
      return ee;
    } else {
      res.removeHeader('Content-Encoding');
      return oraRes;
    }

  };
};