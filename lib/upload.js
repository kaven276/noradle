var CRLF = '\r\n'
  , CRLF2 = '\r\n\r\n'
  , CRLF3 = '\r\n\r\n\r\n'
  , cfg = require('./cfg.js')
  , util = require('./util.js')
  , fs = require('fs')
  , C = require('./constant.js')
  ;

try {
  var formidable = require('formidable');
  var uploadTrim = cfg.upload_dir.length;
} catch (e) {
  console.warn('\n[WARN] Can not find/load "formidable" module, so multipart/form-data file upload is not supported !');
  console.info('You can run "npm -g install formidable" to install formidable nodeJS module.\n');
}

module.exports = function(req, oraSock, next){

  if (!formidable) {
    oraSock.write(CRLF2);
    // todo: cleanup and release resource
    next(new Error(req.url + ' has file upload that is not support without formidable module'));
    return;
  }
  var form = new formidable.IncomingForm();
  var fields = {};
  var dirs = {};
  form.uploadDir = cfg.upload_dir;
  form.keepExtensions = true;

  form.on('field', function(field, value){
    if (field.substr(0, 1) === '_') {
      dirs[field.substr(1)] = value;
    } else {
      if (fields[field]) fields[field].push(value);
      else fields[field] = [value];
    }
  })
    .on('fileBegin', function(field, file){
      var rpath;
      if (file.name === '') {
        file.path = cfg.upload_dir + '/zero';
        return;
      }
      if (dirs[field]) {
        switch (dirs[field].substr(-1)) {
          case '/':
            rpath = dirs[field] + file.name;
            break;
          case '.':
            rpath = dirs[field] + file.name.split('.').pop();
            break;
          default:
            rpath = dirs[field];
        }
      } else {
        rpath = file.path.split('/').pop();
        switch (cfg.upload_depth || 2) {
          case 1:
            break;
          case 2:
            rpath = rpath.substr(0, 16) + '/' + rpath.substr(16);
            break;
          case 3:
            rpath = rpath.substr(0, 10) + '/' + rpath.substr(10, 10) + '/' + rpath.substr(20);
            break;
          case 4:
            rpath = rpath.substr(0, 8) + '/' + rpath.substr(8, 8) + '/' + rpath.substr(16, 8) + '/' + rpath.substr(24);
            break;
          default:
            rpath = rpath.substr(0, 16) + '/' + rpath.substr(16);
        }
        rpath = 'auto/' + rpath;
      }
      util.ensureDir(rpath);
      file.path = cfg.upload_dir + rpath;
      var value = file.path.substr(uploadTrim);
      if (fields[field]) fields[field].push(value);
      else fields[field] = [value];
    })
    .on('file', function(field, file){
      // strip <script>...</script> for html
      if (!file.name || file.size === 0) return;
      var ext = file.name.split('.').pop();
      if (!ext && file.mime() !== 'text/html') return;
      if (ext.match(/(html|htm)/ || file.mime() === 'text/html')) {
        // console.warn('html file "%s" upload to "%s", it may contain harmful script', file.name, file.path);
        fs.readFile(file.path, 'UTF8', function(err, data){
          if (err) {
            console.error('Can not strip script tag in html file "%s" !', file.path);
            return;
          }
          data = data.replace(/<\s*script[^<>]+>(.|\n|\r)*?<\/\s*script\s*>/gim,
            "<em>The script tag and it's content has been striped for security reason at the time of file upload!</em>");
          fs.writeFile(file.path, data, function(err){
            if (err) console.warn('html upload file "%s" can not be striped of script tag !');
          });
        });
        return;
      }
    })
    .on('end', function(){
      var ora_post = [];
      for (var n in fields) {
        var val = fields[n];
        ora_post.push(n, val.join(','));
      }
      if (ora_post.length) {
        oraSock.write(ora_post.join(CRLF) + CRLF3);
      } else {
        oraSock.write(CRLF2);
      }
      oraSock.write(C.REQ_END_MARK);
    })
    .on('error', function(e){
      // todo: clean up and release resource
      next(e);
    })
    .parse(req);
};