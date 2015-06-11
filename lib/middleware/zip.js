var EE = require('events').EventEmitter
  , debug = require('debug')('noradle:zip')
  , zlib = require('zlib')
  , zipMap = exports.zipMap = {
    'gzip' : zlib.createGzip,
    'deflate' : zlib.createDeflateRaw
  };

function chooseZip(acceptEncoding){
  // from the NodeJS available methods, choose the client supported method with the highest priority
  v_zips = acceptEncoding || '';
  if (~v_zips.indexOf('gzip')) {
    return 'gzip';
  }
  if (~v_zips.indexOf('deflate')) {
    return 'deflate';
  }
}

// must be the last filter
exports.zipFilter = function(oraRes, ohdr, flags, res){
  var ee = new EE()
    , method = chooseZip(flags.acceptEncoding)
    ;

  function cacheHead(method, thres){
    debug('cacheHead method=%s, thres=%d', method, thres);
    flags.headFixed = false;
    var compress
      , aLen = 0
      , headBuf = []
      , over = false
      ;

    function doZip(){
      debug('doZip');
      ohdr['Content-Encoding'] = method;
      ohdr['Transfer-Encoding'] = 'chunked';
      if (ohdr['Content-Length']) {
        ohdr['x-pw-content-length'] = ohdr['Content-Length'];
        delete ohdr['Content-Length'];
      }
      debug('doZip write head status=%j', oraRes);
      //res.writeHead(oraRes.status, ohdr);

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

    oraRes.on('end', function(chunks){
      if (chunks) {
        chunks.forEach(function(chunk){
          oraRes.emit('data', chunk);
        });
      }
      if (over) {
        compress.end();
      } else {
        delete ohdr['Content-Encoding'];
        if (!ohdr['Content-Length']) {
          ohdr['Content-Length'] = aLen;
          delete ohdr['Transfer-Encoding'];
        }
        ee.emit('end', headBuf);
      }
    });
  }

  if (!method) {
    delete ohdr['Content-Encoding'];
    return oraRes;
  } else if (ohdr['Content-Encoding'] === 'zip') {
    cacheHead(method, 0);
    return ee;
  } else if (ohdr['Content-Encoding'] === '?') {
    cacheHead(method, flags.zip_threshold || 1000);
    return ee;
  } else {
    delete ohdr['Content-Encoding'];
    return oraRes;
  }

};
