var zlib = require('zlib');

exports.zipMap = {
  'gzip' : zlib.createGzip,
  'deflate' : zlib.createDeflateRaw
}

exports.chooseZip = function(req){
  // from the NodeJS available methods, choose the client supported method with the highest priority
    v_zips = res.headers['accept-encoding'];
  var v_zip = req;
  if (typeof req === 'object') {
  }
  if (~v_zips.indexOf('gzip')) {
    return 'gzip';
  }
  if (~v_zips.indexOf('deflate')) {
    return 'deflate';
  }
}