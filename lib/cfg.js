var path = require('path');
var defCfg = {
  oracle_port : 1521, // accept oracle reversed connection to establish communication path between nodeJS and oracle
  http_port : 80, // port that accept browser(client) http request
  https_port : 443, // port that accept browser(client) https request
  ssl_key : undefined, // server side ssl key text for https service
  ssl_cert : undefined, // server side ssl certification text for https service
  accept_count : 10, // accept connection queue limits, when all oracle socket is in use, requests will go to queue.
  keepalive_timeout : 1200, // browser to server keepalive timeout, default to 20 minutes

  plsql_mount_point : '/', // where to mount all plsql page for combined server
  file_mount_point : '/', // where to mount all static file for combined server

  oneDay : 24 * 60 * 60,
  favicon_path : path.join(__dirname, '../public/favicon.ico'), // where is the site's favicon icon at
  favicon_max_age : 24 * 60 * 60, // how long is browser hold the favicon in cache
  demoDir : path.join(__dirname, '../static/demo'),
  pspDir : path.join(__dirname, '../static/psp'),
  docDir : path.join(__dirname, '../doc'),
  static_root : path.join(__dirname, '../static'), // specify where the static file root directory is at
  show_dir : false, // by default, do not expose directory structure for end users
  upload_dir : path.join(__dirname, '../upload'), // specify upload root directory
  upload_depth : 4, // can specify 1,2,3,4, to divide the 16 byte random string to parts to avoid too big directory, default/more is 2

  zip_threshold : 1024, // if a Content-Length > this, Noradle psp.web will try to compress the response to client
  zip_min_radio : 2 / 3, // if compressed data length less than the setting, compressed data can be used for cache
  use_gw_cache : true, // if NodeJS http gateway will cache response and serve future request when cache hit

  host_base_parts : 2, // specify the number of suffix parts in host dns name, the remaining head in host is host prefix
  server_name : 'Noradle - PSP.WEB', // specify the value of http response header "server_name“

  DBPoolCheckInterval : 1000, // at what interval dose db pool monitor checks timeouts(in milliseconds)
  HalfWayTimeout : 500, // over this threshold(in milliseconds), half way fb/css will timeout for RC recycling
  ExecTimeout : 3000, // over this threshold(in milliseconds), if execution got no response, timeout it for RC recycling
  FreeConnTimeout : 3000, // over this threshold(in milliseconds), if no free db connection to use, timeout the request

  dummy : undefined // just keep it for diff friendly
};


var setting;
try {
  setting = require('../setting.js');
}
catch (e) {
  console.info('You should provide setting.js file for server configuration.');
  console.info('A absent or empty setting.js file will tell server to use default configuration from lib/cfg.js.')
  console.info('You can copy lib/cfg.js to setting.js and modify it for your purpose.');
  console.info('If a configuration item is not set in setting.js, the default value will come from lib/cfg.js.');
  console.info();
}

var cfg = require('./util.js').override(defCfg, setting);
module.exports = require('./util.js').override(defCfg, setting);

require('./util.js').ensureDir(cfg.upload_dir);