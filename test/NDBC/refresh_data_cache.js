/**
 * Created by cuccpkfs on 14-12-31.
 */

var Noradle = require('noradle')
  , inspect = require('util').inspect
  , cacheUsers
  ;

var dbPool = new Noradle.DBPool(1522, {
  FreeConnTimeout : 60000
});
var dbc = new Noradle.NDBC(dbPool);

// update cacheUsers data from database every 10s
dbc.call('demo1.user_b.data_src', {
  __parse : true,
  __ignore_error : true,
  __interval : 10 * 1000
}, function(status, headers, jsobject){
  cacheUsers = jsobject;
  console.log('\n\n\n');
  console.log(inspect(jsobject, {depth : 8}));
});
