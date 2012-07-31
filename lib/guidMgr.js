/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-7-27
 * Time: 下午2:30
 */

var lastMs = Date.now() - 1
  , seqInMs
  , crypto = require('crypto')
  ;

function create(cb){
  var now = Date.now()
    , md5sum = crypto.createHash('md5')
    , buf = new Buffer(8)
    , result
    ;
  if (lastMs === now) {
    seqInMs++;
  } else {
    lastMs = now;
    seqInMs = 0;
  }
  md5sum.update(String(now) + ':' + String(seqInMs));
  result = md5sum.digest('base64').slice(0, 22);
  if (cb) {
    cb(result);
  } else {
    return result;
  }
}

exports.create = create;
