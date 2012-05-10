var cfg = require('./cfg.js');

var favicon = {
  status : 404,
  headers : {}
};

(function load_favicon(){
  require('fs').readFile(cfg.favicon_path, function(err, buf){
    if (err) {
      var errinfo = 'favicon is not found!';
      favicon = {
        status : 404,
        headers : {
          'Content-Type' : 'text/plain',
          'Content-Length' : errinfo.length
        },
        body : errinfo
      }
    } else {
      favicon = {
        status : 200,
        headers : {
          'Content-Type' : 'image/x-icon',
          'Content-Length' : buf.length,
          'Cache-Control' : 'public, max-age=' + cfg.favicon_max_age
        },
        body : buf
      };
    }
    setTimeout(load_favicon, cfg.favicon_max_age * 1000);
  });
})();

module.exports = favicon;
