"use strict";
var path = require('path')
  ;

// from request parsing/handling to response filter to platform config
module.exports = {
  status_url : '/server-status',

  omit_file_url : true, // if check url is for static file, true to bypass
  use_negotiation : true, // if parse accept* to ordered array for ReqBase
  use_proxy : true, // if trust x-forwarded-(proto|for|port)
  strip_tag : true, // if stripe tag for parameter value from query-string or form-submit or json-post
  url_pattern : '/x$prog', // like /x$gid/x$dbu/x$prog, for parsing url to core execution environment
  x$dbu : '', // default database user
  x$prog : '', // default servlet name
  x$prog1 : '', // default servlet name for url "/?"
  x$prog2 : '', // default servlet name for url "/path1/?"
  x$prog3 : '', // default servlet name for url "/path1/path2/?"
  x$before : 'k_filter.before',
  x$after : 'k_filter.after',
  package_map : {}, // map long prog name(>30 char) to short name
  u$location : '', // if parent path sect before x$prog is also miss, redirect to this url
  h$ : true, // if send req.headers NV
  c$ : true, // if send req.cookies NV
  a$ : true, // if get client/server address info and send NV
  l$ : './', // default static url root
  t$ : false, // if trace timespan for steps of a reqeust, producing timespan
  f$feedback : 'Y', // if enable automatically feedback for post request
  adjust_env_func : null, // function(reqBase) to adjust ReqBase env name-value pairs

  upload_dir : path.join(process.argv[1], '../upload/'), // specify upload root directory
  upload_depth : 4, //  can be 1,2,3,4, to split 16 byte random string to parts to avoid too big directory

  server_name : 'Noradle - PSP.WEB', // specify the value of http response header "x-powered-by“

  GatewayCache : true, // true to use default GatewayCache, or set to customized GatewayCache

  template_dir : '', // where template place
  template_engine : 'jade', // default template engine name
  template_map : {
    'hbs' : 'handlebars',
    'mst' : 'mustache'
  },
  converters : {}, // set named converters like markdown

  zip_threshold : 1024, // if a Content-Length > this, Noradle psp.web will try to compress the response to client
  zip_min_radio : (2 / 3), // if compressed data length is less than the setting, compressed data can be used for cache

  accept_count : 10, // accept connection queue limits, when all oracle socket is in use, requests will go to queue.
  oracle_keep_alive : 1 * 60 * 60, // seconds, keep alive to hod NAT state; 0,false to close keep alive
  DBPoolCheckInterval : 1000, //  interval(in milliseconds) db pool monitor checks "executing-but-no-response" timeouts
  ExecTimeout : 3000, // over this threshold(in milliseconds), if execution got no response, timeout it for RC recycling
  FreeConnTimeout : 3000, // over this threshold(in milliseconds), if no free db connection to use, timeout the request

  check_session_hijack : false, // if enable the browser session hijack detection
  NoneBrowserPattern : /^$/, // all user-agent match this will not generate msid/bsid cookies automatically.
  GuardUpdateInterval : 60, // after this seconds, next request must update the session guard value
  GuardCleanInterval : 20, // after this minutes, Noradle will cleanup long idle session guard records

  dummy : undefined // just keep it for diff friendly
};
