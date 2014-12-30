/**
 * Created by cuccpkfs on 14-12-30.
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
  __ignore_error : true,
  timeout : 1
});

var callin = new Noradle.NDBC(dbPool, {});

callout.call('demo1.msg_b.compute_callout', {timeout : 1}, function(status, headers, messages){
  var p = messages.split('\n')
    , p1 = parseInt(p[0])
    , p2 = parseInt(p[1])
    ;
  console.log('compute input params', p1, p2);
  callin.call('demo1.msg_c.compute_callback', {h$pipename : 'cb', result : p1 + p2});
});
