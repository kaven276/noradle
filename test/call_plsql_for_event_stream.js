/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-6
 * Time: 上午11:19
 */

var Noradle = require('..')
  , dbc = new Noradle.DBCall('demo', 'theOnlyDB')
  , msgStream
  , count = 0
  , plsql
  , params = {}
  ;
console.log(Noradle.gracefulExit.toString());
switch (3) {
  case 1: // call for continuously message stream, one message one emit or one callback
    plsql = 'callout_broker_h.emit_messages';
    break;
  case 2: // call for user change stream, use bkr.write_event in trigger and bkr.read_event in broker
    plsql = 'callout_broker_h.user_change_manual_stream';
    Noradle.gracefulExit(function(){
      console.log('exiting...');
      dbc.call('bkr.stop', {}, function(err, msg){
        console.log('stopping stream result', err, msg)
      });
    });
    break;
  case 3:
    plsql = 'auto_stream_h';
    params = {'stream_name' : 'demo_user_upt', 'handler_name' : 'callout_broker_h.user_change_handler'};
    break;
}

msgStream = dbc.call(plsql, params, function(err, msg){
  if (err) {
    console.error('error:', err, msg);
    process.exit(2);
  } else if (!msg) {
    console.log('The End');
    return;
  }
  console.log('\nNO.%d message arrived @callback:', ++count);
  console.log(msg);
});

// essential when the source message stream will be propagated to more than one destinations
msgStream.on('message', function(msg){
  console.log('message (%s) is sent(synchronized) to www.sina.com.cn', msg.replace(/\n$/, ''));
});
msgStream.on('message', function(msg){
  console.log('message (%s) is sent(synchronized) to www.tencent.com', msg.replace(/\n$/, ''));
});
dbc.on('message', function(msg){
  console.log('message (%s) is captured at DBCall level', msg.replace(/\n$/, ''));
});

msgStream.on('finish', function(){
  console.log('End of msgStream');
});
