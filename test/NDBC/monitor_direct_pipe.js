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
  pipename : 'direct_send_pipe',
  timeout : 1
});

var callin = new Noradle.NDBC(dbPool, {});

var linefeed = String.fromCharCode(30) + '\n'
  ;

callout.call('demo1.msg_b.pipe2node', {timeout : 1}, function(status, headers, messages){
  var p = messages.split(linefeed)
    , oper = p[0]
    , p1 = parseInt(p[1])
    , p2 = parseInt(p[2])
    , pipename = p[3]
    , result
    ;
  console.log('callout input params', p);
  if (pipename) {
    switch (oper) {
      case 'add':
        result = p1 + p2;
        break;
      case 'minus':
        result = p1 - p2;
        break;
      case 'multiply':
        result = p1 * p2;
        break;
      default:
        result = 0;
    }
    // need call back with response to oracle
    callin.call('demo1.msg_b.resp_oper_result', {h$pipename : pipename, oper : oper, result : result});
  }
});
