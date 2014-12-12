var zlib = require('zlib')
  , zipMap = exports.zipMap = {
    'gzip' : zlib.createGzip,
    'deflate' : zlib.createDeflateRaw
  };

exports.chooseZip = function(req){
  // from the NodeJS available methods, choose the client supported method with the highest priority
  var v_zip = req;
  if (typeof req === 'object') {
    v_zips = req.headers['accept-encoding'] || '';
  }
  if (~v_zips.indexOf('gzip')) {
    return 'gzip';
  }
  if (~v_zips.indexOf('deflate')) {
    return 'deflate';
  }
};

exports.zipFilter = function(oraRes, option){
  var method = option.method
    , compress = zipMap[method]()
    ;

  oraRes.on('data', function(data){
    compress.write(data);
  });

  oraRes.on('end', function(){
    compress.end();
  });

  return compress;
};
