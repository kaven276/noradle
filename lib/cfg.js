var path = require('path')
  ;

module.exports = {
  oracle_port : 1522, // accept oracle reversed connection to establish communication path between nodeJS and oracle
  http_port : 8080, // port that accept browser(client) http request
  https_port : 443, // port that accept browser(client) https request
  static_port : 8000, // port that serve static files solely
  static_ssl_port : 8443, // port that serve static files solely
  ssl_key : undefined, // server side ssl key text for https service
  ssl_cert : undefined, // server side ssl certification text for https service
  accept_count : 10, // accept connection queue limits, when all oracle socket is in use, requests will go to queue.
  check_session_hijack : false, // if enable the browser session hijack detection

  plsql_mount_point : '/', // where to mount all plsql page for combined server
  file_mount_point : '/fs', // where to mount all static file for combined server

  oneDay : 24 * 60 * 60,
  favicon_path : path.join(__dirname, '../public/favicon.ico'), // where is the site's favicon icon at
  favicon_max_age : 24 * 60 * 60, // how long is browser hold the favicon in cache
  demoDir : path.join(__dirname, '../static/demo'),
  pspDir : path.join(__dirname, '../static/psp'),
  docDir : path.join(__dirname, '../doc'),
  static_root : path.join(__dirname, '../static'), // specify where the static file root directory is at
  show_dir : true, // by default, do not expose directory structure for end users
  upload_dir : path.join(__dirname, '../upload'), // specify upload root directory
  upload_depth : 4, //  can be 1,2,3,4, to split 16 byte random string to parts to avoid too big directory

  zip_threshold : 1024, // if a Content-Length > this, Noradle psp.web will try to compress the response to client
  zip_min_radio : 2 / 3, // if compressed data length is less than the setting, compressed data can be used for cache
  use_gw_cache : true, // if NodeJS http gateway will cache response and serve future request when cache hit

  host_base_parts : 2, // specify the number of suffix parts in host dns name, the remaining head in host is host prefix
  server_name : 'Noradle - PSP.WEB', // specify the value of http response header "x-powered-by“

  DBPoolCheckInterval : 1000, //  interval(in milliseconds) db pool monitor checks "executing-but-no-response" timeouts
  ExecTimeout : 3000, // over this threshold(in milliseconds), if execution got no response, timeout it for RC recycling
  FreeConnTimeout : 3000, // over this threshold(in milliseconds), if no free db connection to use, timeout the request

  NoneBrowserPattern : /^$/, // all user-agent match this will not generate msid/bsid cookies automatically.
  GuardUpdateInterval : 60, // after this seconds, next request must update the session guard value
  GuardCleanInterval : 20, // after this minutes, Noradle will cleanup long idle session guard records

  dummy : undefined // just keep it for diff friendly
};
