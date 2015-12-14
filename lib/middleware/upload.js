"use strict";
var cfg = require('./../cfg.js')
  , util = require('./../util/util.js')
  , fs = require('fs')
  , debug = require('debug')('noradle:upload')
  ;

try {
  var formidable = require('formidable');
} catch (e) {
  console.warn('\n[WARN] Can not find/load "formidable" module, so multipart/form-data file upload is not supported !');
  console.info('You can run "npm -g install formidable" to install formidable nodeJS module.\n');
}

module.exports = function(cfg){

  if (cfg.upload_dir.substr(-1) !== '/') {
    cfg.upload_dir += '/';
  }

  var uploadTrim = cfg.upload_dir.length;

  return function(req, postHeaders, sendAll, next){

    debug('on upload, %s', req.url);

    if (!formidable) {
      // todo: cleanup and release resource
      next(new Error(req.url + ' has file upload that is not support without formidable module'));
      return;
    }
    var form = new formidable.IncomingForm();
    var fields = postHeaders;
    var dirs = {};
    form.uploadDir = cfg.upload_dir;
    form.keepExtensions = true;

    form.on('field', function(field, value){
      debug('on field, %s, %s', field, value);
      if (field.substr(0, 1) === '_') {
        dirs[field.substr(1)] = value;
      } else {
        if (fields[field]) fields[field].push(value);
        else fields[field] = [value];
      }
    })
      .on('fileBegin', function(field, file){
        debug('on fileBegin, %s, %s', field, file);
        var rpath;
        if (file.name === '') {
          file.path = cfg.upload_dir + 'null';
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
        util.ensureDir(cfg.upload_dir + rpath);
        file.path = cfg.upload_dir + rpath;
      })
      .on('file', function(field, file){
        debug('on file, %s, %s', field, file);
        var value = file.path.substr(uploadTrim);
        if (value === 'null') {
          value = '';
        }
        if (fields[field]) {
          fields[field].push(value);
          fields[field + '.size'].push(file.size);
        } else {
          fields[field] = [value];
          fields[field + '.size'] = [file.size];
        }
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
        }
      })
      .on('end', function(){
        sendAll();
      })
      .on('error', function(e){
        // todo: clean up and release resource
        postHeaders['e$upload'] = e.toString();
        sendAll();
      })
      .parse(req);
  };
};
