/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-17
 * Time: 下午2:42
 */

var crypto = require('crypto')
  , createHash = crypto.createHash
  , EE = require('events').EventEmitter
  ;

module.exports = function MD5CalcFilter(oraRes, ohdr, flags){
  if (ohdr['Content-MD5'] === '?') ; else {
    return oraRes;
  }
  var chunks = []
    , count = 0
    , hash = createHash('md5')
    , ee = new EE()
    ;
  console.log('in filter', ohdr);
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
    console.log('in filter end', ohdr);
    chunks.forEach(function(chunk){
      ee.emit('data', chunk);
    });
    ee.emit('end');
  });
  flags.headFixed = false;
  return ee;
};
