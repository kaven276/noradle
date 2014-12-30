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
var dbc = new Noradle.NDBC(dbPool, {
  __parse : true,
  __repeat : true,
  __parallel : 2,
  __ignore_error : true,
  timeout : 1
});

dbc.call('demo1.msg_b.sendout_single', {timeout : 1}, function(status, headers, messages){
  if (status !== 200) {
    console.log(no, 'error status is', status);
    return;
  }
  console.log(inspect(messages, {depth : 8}));
});
