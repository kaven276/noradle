module.exports = function(setting){

  var utl = require('./util.js')
    , cfg = require('./cfg.js')
    ;
  utl.override2(cfg, setting);
  cfg.upload_dir && utl.ensureDir(cfg.upload_dir);

  var common = require('./common.js')
    , c = require('connect')
    , app = c.createServer()
    ;

// 1. for favicon
  app.use(c.favicon(cfg.favicon_path, {maxAge : cfg.favicon_max_age}));
  common.mount_doc(app);
  app.use(cfg.file_mount_point, common.mount_static(c.createServer()));
  app.use(cfg.plsql_mount_point || '/', require('./psp.web.js'));

  console.info('This is combined/integrated server (service both dynamic PL/SQL page and static file) ');
  console.info('Usage: Noradle.runCombined({ oracle_port:1521, http_port:80, https_port:443 ... });');

  common.start_dynamic(app);
};

