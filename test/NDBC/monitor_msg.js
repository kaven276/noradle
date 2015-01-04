/**
 * Created by cuccpkfs on 14-12-25.
 */

var Noradle = require('noradle')
  , log = console.log
  , parse = Noradle.RSParser.rsParse
  , inspect = require('util').inspect
  ;

var dbPool = new Noradle.DBPool(1522, {
  FreeConnTimeout : 60000
});
var dbc = new Noradle.NDBC(dbPool, {
  __parse : false
});

function getMsg(no){
  (function listen(){
    dbc.call('demo1.msg_b.sendout_single', {timeout : 1}, function(status, headers, messages){
      process.nextTick(listen);
      if (status !== 200) {
        console.log(no, 'status is', status);
        if (status === 504) {
          // console.log('monitor new message timeout.');
        }
        return;
      }
      // process messages
      console.log(inspect(messages, {depth : 8}));
    });
  })();
}

function startMessageProcessing(parallel){
  for (var i = 0; i < parallel; i++) {
    getMsg(i);
  }
}

startMessageProcessing(2);