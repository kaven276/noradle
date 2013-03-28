var fs = require('fs')
  , uploadDir
  , crypto = require('crypto')
  , createHash = crypto.createHash
  ;

process.nextTick(function(){
  uploadDir = require('./cfg.js').upload_dir;
});

// todo : must support async method, or it will block the only execution thread
exports.ensureDir = function(path){
  var sects = path.split('/');
  var len = sects.length - 1;
  for (var i = len; i > 0; i--) {
    var tryPath = uploadDir + sects.slice(0, i).join('/');
    try {
      var stat = fs.statSync(tryPath);
      // if (stat.isDirectory()) ...;
    } catch (e) {
      continue;
    }
    break;
  }
  for (var j = i; j < len; j++) {
    tryPath = uploadDir + sects.slice(0, j + 1).join('/');
    fs.mkdirSync(tryPath);
  }
}

exports.override = function(def, setting){
  var cfg = {};
  for (var n in def)
    if (setting[n])
      cfg[n] = setting[n];
    else
      cfg[n] = def[n];
  return cfg;
}

exports.override2 = function(def, setting){
  setting = setting || {};
  for (var n in def)
    if (n in setting)
      def[n] = setting[n];
    else
      def[n] = def[n];
  return def;
}

exports.find = function(arr, item, func){
  func = func || function(p){
    return p;
  };
  for (var i = 0, len = arr.length; i < len; i++) {
    if (func(arr[i]) === item)
      return i;
  }
  return -1;
}

exports.makeArray = function(size){
  var r = new Array(size);
  for (var i = 0; i < size; i++) r[i] = i;
  return r;
}

exports.dummy = function(){
  ;
}

var ranges = [
  [32, 42],
  [44, 46],
  [58, 60],
  [62, 64],
  [91, 96],
  [123, 126]
];
var charMap = [];
ranges.forEach(function(span){
  for (var i = span[0]; i <= span[1]; i++) {
    charMap.push(String.fromCharCode(i));
  }
});
charMap = charMap.join('');

function base64alt(hash){
  return hash.replace(/[a-z]/g, function(char){
    return charMap[char.charCodeAt(0) - 97];
  });
}
// console.log(exports.base64alt('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/='));

function hash(value){
  return createHash('md5').update(value || '').digest('base64').slice(0, 22);
}

function hash2(value){
  return base64alt(hash(value));
}

exports.base64alt = base64alt;
exports.hash = hash;
exports.hash2 = hash2;

exports.random = function(){
  return crypto.randomBytes(4).toString('hex');
}

exports.gracefulExit = function(beforeExit){
  process.on('SIGTERM', beforeExit); // kill or kill -15
  process.on('SIGINT', beforeExit); // Ctrl-C
  process.on('SIGQUIT', beforeExit); // press quit7
  process.on('SIGTSTP', beforeExit);
  process.on('SIGHUP', beforeExit); // when logout
  process.on('SIGKILL', beforeExit); // kill -9

  process.on('exit', function(){
    console.log('To be exit.');
  });
};


if (process.argv[1] === __filename) {
  console.log(charMap);
}