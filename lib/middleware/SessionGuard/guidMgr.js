/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-7-27
 * Time: 下午2:30
 * generate a GUID across all host:port, and across all the time span,
 * and protected by changing secret against next GUID or valid history GUID guessing
 */

var lastMs = Date.now() - 1
  , seqInMs
  , crypto = require('crypto')
  , createHmac = crypto.createHmac
  , secret = require('./secret.js')
  ;

function create(stripe, cb){
  var now = Date.now();
  if (lastMs === now) {
    seqInMs++;
  } else {
    lastMs = now;
    seqInMs = 0;
  }
  var src = [ stripe , String(now), String(seqInMs)].join(':');
  var result = createHmac('md5', secret.getCurrentSecret()).update(src, 'ascii').digest('base64').slice(0, 22);
  if (cb) {
    cb(result);
  } else {
    return result;
  }
}

exports.create = create;

if (process.argv[1] === __filename) {
  console.log(create('a'));
}
