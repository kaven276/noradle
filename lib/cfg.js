var path = require('path')
  ;

module.exports = {
  accept_count : 10, // accept connection queue limits, when all oracle socket is in use, requests will go to queue.
  check_session_hijack : false, // if enable the browser session hijack detection
  status_url : '/server-status',
  favicon_url : 'http://nodejs.org/favicon.ico',

  plsql_mount_point : '/', // where to mount all plsql page for combined server
  file_mount_point : '/fs', // where to mount all static file for combined server
  req_nv : undefined, // function to fill name-value pairs got from request info
  url_map : true, // if do url to servlet mapping

  oracle_keep_alive : 1 * 60 * 60, // seconds, keep alive to hod NAT state; 0,false to close keep alive

  oneDay : 24 * 60 * 60,
  favicon_path : path.join(__dirname, '../public/favicon.ico'), // where is the site's favicon icon at
  favicon_max_age : 24 * 60 * 60, // how long is browser hold the favicon in cache
  upload_dir : path.join(__dirname, '../upload/'), // specify upload root directory
  upload_depth : 4, //  can be 1,2,3,4, to split 16 byte random string to parts to avoid too big directory

  zip_threshold : 1024, // if a Content-Length > this, Noradle psp.web will try to compress the response to client
  zip_min_radio : 2 / 3, // if compressed data length is less than the setting, compressed data can be used for cache
  use_gw_cache : false, // if NodeJS http gateway will cache response and serve future request when cache hit

  host_base_parts : 2, // specify the number of suffix parts in host dns name, the remaining head in host is host prefix
  server_name : 'Noradle - PSP.WEB', // specify the value of http response header "x-powered-by“

  DBPoolCheckInterval : 1000, //  interval(in milliseconds) db pool monitor checks "executing-but-no-response" timeouts
  ExecTimeout : 3000, // over this threshold(in milliseconds), if execution got no response, timeout it for RC recycling
  FreeConnTimeout : 3000, // over this threshold(in milliseconds), if no free db connection to use, timeout the request

  NoneBrowserPattern : /^$/, // all user-agent match this will not generate msid/bsid cookies automatically.
  GuardUpdateInterval : 60, // after this seconds, next request must update the session guard value
  GuardCleanInterval : 20, // after this minutes, Noradle will cleanup long idle session guard records

  GatewayCache : true, // true to use default GatewayCache, or set to customized GatewayCache
  template_dir : '', // where template place
  template_engine : 'jade', // default template engine name
  template_map : {
    'hbs' : 'handlebars',
    'mst' : 'mustache'
  },
  package_map : {}, // map long prog name(>30 char) to short name

  dummy : undefined // just keep it for diff friendly
};
