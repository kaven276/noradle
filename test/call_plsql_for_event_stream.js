/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-6
 * Time: 上午11:19
 */

var Noradle = require('..')
  , dbc = new Noradle.DBCall('demo', 'theOnlyDB')
  ;

Noradle.connectionMonitor.once('connect', UnitTest);

function UnitTest(){
  var msgStream
    , count = 0
    , plsq
    , params = {}
    ;

  switch (1) {
    case 1: // call for continuously message stream, one message one emit or one callback
      plsql = 'callout_broker_h.emit_messages';
      break;
    case 2:
      plsql = 'bkr.auto_stream';
      params = {'stream_name' : 'demo_user_upt'};
      break;
  }

  msgStream = dbc.call(plsql, params, function(err, msg){
    if (err) {
      console.error(status);
      process.exit(2);
    } else if (!msg) {
      console.log('The End');
      //return;
    }
    console.log('\nNO.%d message arrived @callback:', ++count);
  });

  // essential when the source message stream will be propagated to more than one destinations
  msgStream.on('message', function(msg){
    console.log('message (%s) is sent(synchronized) to www.sina.com.cn', msg.replace(/\n$/, ''));
  });
  msgStream.on('message', function(msg){
    console.log('message (%s) is sent(synchronized) to www.tencent.com', msg.replace(/\n$/, ''));
  });

  msgStream.on('end', function(){
    console.log('End of msgStream');
  });
}