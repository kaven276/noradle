/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-7-27
 * Time: 下午2:30
 */

var lastMs = Date.now() - 1
  , seqInMs
  , crypto = require('crypto')
  , secret = require('./cfg.js').CookieSecret
  ;

function create(cb){
  var now = Date.now();
  if (lastMs === now) {
    seqInMs++;
  } else {
    lastMs = now;
    seqInMs = 0;
  }
  var src = [secret , String(now), String(seqInMs)].join(':');
  var result = crypto.createHash('md5').update(src, 'ascii').digest('base64').slice(0, 22);
  if (cb) {
    cb(result);
  } else {
    return result;
  }
}

exports.create = create;