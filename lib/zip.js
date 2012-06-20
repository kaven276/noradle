var zlib = require('zlib');

exports.zipMap = {
  'gzip' : zlib.createGzip,
  'deflate' : zlib.createDeflateRaw
}

exports.chooseZip = function(res){
  // from the NodeJS available methods, choose the client supported method with the highest priority
  var v_zip = res;
  if (typeof res === 'object') {
    v_zips = res.headers['accept-encoding'];
  }
  if (~v_zips.indexOf('gzip')) {
    return 'gzip';
  }
  if (~v_zips.indexOf('deflate')) {
    return 'deflate';
  }
}