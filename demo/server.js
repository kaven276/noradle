/**
 * Created by cuccpkfs on 14-12-17.
 */

var cfg = require('./cfg.js')
  , http = require('http')
  , noradle = require('noradle')
  , harp = require('harp')
  , connect = require('connect')
  , app = connect.createServer()
  , port = cfg.http_port
  , port2 = port + 1000
  , y$static = cfg.static_url + cfg.demo_dbu + '/'
  ;

var dbPool = new noradle.DBPool(cfg.oracle_port, {
  oracle_keep_alive : cfg.oracle_keep_alive
});

function ReqBaseC(req){
  this.y$static = y$static;
}

// set url routes
{

  app.use(noradle.servlet(dbPool, ReqBaseC, {
    check_session_hijack : false,
    NoneBrowserPattern : /^$/,
    static_url : cfg.static_url,
    upload_dir : cfg.upload_dir,
    favicon_url : y$static + 'favicon.ico'
  }));

  app.use(y$static, connect.static(cfg.static_root, {
    maxAge : cfg.oneDay,
    redirect : false
  }));

  app.use(y$static, harp.mount(cfg.static_root));

}

/**
 * start a combined http server, which inlucde
 * plsql servlet, static file, harp compiler
 */
http.createServer(app).listen(port, function(){
  console.log('http server is listening at ' + port);
});

/**
 * You can watch DBPool status at another http server instance
 */
http.createServer(noradle.poolMonitor.showStatus).listen(port2, function(){
  console.log('http monitor server is listening at ' + port2);
});
