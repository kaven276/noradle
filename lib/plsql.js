var utl = require('./util.js')
  ;

module.exports = function(setting){
  var cfg = require('./cfg.js');
  utl.override2(cfg, setting);
  cfg.upload_dir && utl.ensureDir(cfg.upload_dir);

  console.info('This is sole pl/sql dynamic page server (service only PL/SQL page)');
  console.info('Static file should be served on another server for better proformance and CDN');
  console.info('Usage: Noradle.runPSP4WEB({ oracle_port:1521, http_port:80, https_port:443... });');

  require('./common.js').start_dynamic(require('./psp.web.js'));
};
