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
  __parse : true,
  timeout : 1
});

var callin = new Noradle.NDBC(dbPool, {});

/**
 * you can fetch multiple types of call-out messages from one named pipe
 * use header to differentiate them
 */
callout.call('demo1.mp_h.fetch_msg', function(status, headers, message){
  var msgType = headers['Msg-Type'];
  switch (msgType) {
    case 'type1':
      console.log('type 1 message received.');
      break;
    case 'type2':
      console.log('type 2 message received.');
      break;
    case 'type3':
      console.log('type 3 message received.');
      break;
    case 'type4':
      console.log('type 4 message received.');
      // mimic call external service to get result and send it back to oracle as synchronized call return value
      setTimeout(function(){
        callin.call('demo1.mp_h.node2pipe', {h$pipename : headers['Callback-Pipename'], temperature : -3});
      }, 1000);

      break;
  }
  console.log(headers);
  console.log(message);
});
