/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-17
 * Time: 下午2:42
 */

var bUnitTest = (process.argv[1] === __filename)
  , crypto = require('crypto')
  , createHash = crypto.createHash
  ;

function MD5Calc(callback){
  this.callback = callback;
  this.chunks = [];
  this.count = 0;
  this.hash = createHash('md5');
}

MD5Calc.prototype.writable = true;
MD5Calc.prototype.readable = false;
MD5Calc.prototype.write = function(data){
  if (!data) return true;
  this.chunks.push(data);
  this.count += data.length;
  this.hash.update(data, 'binary');
  return true;
}

MD5Calc.prototype.end = function(data){
  this.write(data);
  this.callback(this.count, this.hash.digest('base64'), this.chunks);
}

MD5Calc.prototype.removeListener = function(){
  ;
}

MD5Calc.prototype.on = function(evt, func){
  ;
}

MD5Calc.prototype.emit = function(evt, data){
  ;
}

exports.Class = MD5Calc;

if (bUnitTest) {
  (function(){
    var md5 = new MD5Calc(function(len, md5, chunks){
      console.log(len);
      console.log(md5);
      console.log(chunks);
    });
    md5.write(new Buffer('abcdefg'));
    md5.write(new Buffer('hijklmn'));
    md5.write(new Buffer('opq rst'));
    md5.end(new Buffer('uvw xyz'));
  })();
}