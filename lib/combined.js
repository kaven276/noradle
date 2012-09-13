var utl = require('./util.js')
  ;

module.exports = function(setting){

  var cfg = require('./cfg.js')
    , common = require('./common.js')
    , c = require('connect')
    , app = c.createServer()
    ;

  utl.override2(cfg, setting);
  cfg.upload_dir && utl.ensureDir(cfg.upload_dir);

// 1. for favicon
  app.use(c.favicon(cfg.favicon_path, {maxAge : cfg.favicon_max_age}));
  common.mount_doc(app);
  app.use(cfg.file_mount_point, common.mount_static(c.createServer()));
  app.use(cfg.plsql_mount_point || '/', require('./psp.web.js'));

  console.info('This is combined/integrated server (service both dynamic PL/SQL page and static file) ');
  console.info('Usage: node combined_server [oracle_port] [client_port] [client_port_ssl]');

  common.start_dynamic(app);
};

