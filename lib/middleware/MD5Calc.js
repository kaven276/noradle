/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-17
 * Time: 下午2:42
 *
 * also convert chunked encoding to Content-Length by the way
 */

var crypto = require('crypto')
  , createHash = crypto.createHash
  , EE = require('events').EventEmitter
  ;

module.exports = function MD5CalcFilter(oraRes, ohdr){
  if (ohdr['Content-MD5'] === '?') ; else {
    return oraRes;
  }
  var chunks = []
    , count = 0
    , hash = createHash('md5')
    , ee = new EE()
    ;
  oraRes.on('data', function(data){
    if (!data) return true;
    chunks.push(data);
    count += data.length;
    hash.update(data, 'binary');
  });
  oraRes.on('end', function(){
    delete ohdr['Transfer-Encoding'];
    ohdr['Content-Length'] = count.toString();
    ohdr['Content-MD5'] = hash.digest('base64');
    for (var i = 0, len = chunks.length; i < len; i++) {
      ee.emit('data', chunks[i]);
    }
    ee.emit('end');
  });
  return ee;
};
