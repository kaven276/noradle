/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-8-2
 * Time: 下午2:49
 * Session guard is send with BSID cookie will alleviate session hijacking to some degree
 * If you use https, it's not needed at all
 */

var secrets = []
  , crypto = require('crypto')
  ;

function random(){
  ;
}

function Secret(){
  this.time = new Date();
  this.value = random();
  secrets.push(combined)
  return fmt(time) + this.value;
}

function fmt(dt){
  ;
}

/**
 * check if the cookie for bsid,guard is valid
 * @param bsid
 * @param dns
 * @param secret
 */
function judge(bsid, dns, guard){
  var time = secret.substr(0, 8);
}

function getCurrentSecret(){
  return 'Noradle psp.web';
}

exports.getCurrentSecret = getCurrentSecret;