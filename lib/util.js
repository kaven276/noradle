var fs = require('fs')
  , uploadDir
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