/**
 * Created by cuccpkfs on 14-12-31.
 */

var Noradle = require('noradle')
  , log = console.log
  , inspect = require('util').inspect
  ;

var dbPool = new Noradle.DBPool(1522, {
  FreeConnTimeout : 60000
});
var callout = new Noradle.NDBC(dbPool, {
  __repeat : true,
  __parallel : 1,
  __ignore_error : false,
  timeout : 1,
  x$dbu : 'public'
});

var callin = new Noradle.NDBC(dbPool, {});

callout.call('mp_h.fetch_msg', {'h$pipename' : 'sync_sendout'}, function(status, headers, message){
  console.log(headers);
  console.log(message);
  // callin.call('demo1.msg_c.compute_callback', {h$pipename : 'cb', result : p1 + p2});
});
