/**
 * Created by cuccpkfs on 14-12-30.
 */

var Noradle = require('noradle')
  , log = console.log
  , inspect = require('util').inspect
  ;

var dbPool = new Noradle.DBPool(1522, {
    FreeConnTimeout : 60000
  })
  , callout = new Noradle.NDBC(dbPool, {
    __parse : true,
    __repeat : true,
    __parallel : 1,
    __ignore_error : true,
    x$dbu : 'public',
    timeout : 1
  })
  , callin = new Noradle.NDBC(dbPool, {
    x$dbu : 'public'
  })
  ;

callout.call('mp_h.pipe2node', {pipename : 'pipe_only'}, function(status, headers, p){
  var pipename = p.pop()
    , oper = p[0]
    , p1 = parseInt(p[1])
    , p2 = parseInt(p[2])
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
    callin.call('mp_h.node2pipe', {
      h$pipename : pipename,
      oper : oper,
      result : result
    });
  }
});
