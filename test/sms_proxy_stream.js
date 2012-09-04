/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-6
 * Time: 上午8:54
 */

require('../lib/cfg.js').oracle_port = 1522;

var SGIP = require('../../sms/node_sms')
  , SP = SGIP.nodeSP.Class
  , Submit = SGIP.msgSubmit.Class
  , Attrs = SGIP.AttrCfg
  , Noradle = require('..')
  , smsLogger = console.log
  , quitFlag = false
  , sp = require('./sms_common_sp.js').sp
  ;

sp.on('request', function(req){
  if (req instanceof SGIP.msgReport.Class) {
    console.log('\nReport:');
  } else if (req instanceof SGIP.msgDeliver.Class) {
    console.log('\nDeliver:');
  }
  console.log(req);
});


var dbc = new Noradle.DBCall('message_proxy', 'theOnlyDB');
var count = 0;

function monitoring(){
  var msgStream = dbc.call('sms_broker_h.monitor', function(err, msg){
    if (err) {
      console.error('\nMessage Stream has error messages :');
      console.error(err);
      return;
    }
    console.log('msg=%s', msg);
    if (!msg || msg.length === 0) return;
    console.log('\nNO.%d message arrived :', ++count);

    var lines = msg.split('\n')
      , rowid = lines.shift()
      , contLCnt = parseInt(lines.shift())
      , cont = lines.splice(0, contLCnt).join('\n')
      , sender = lines.shift()
      , encode = parseInt(lines.shift() || '8')
      , srcenc = lines.shift()
      , UserCount = lines.shift()
      , UserNumbers = lines.splice(0, UserCount)
      , option = { ReportFlag : 1}
      ;
    if (srcenc === 'hex') {
      cont = new buffer(cont, 'hex');
    }
    lines.pop();
    lines.forEach(function(line){
      var nv = line.split(':')
        , n = nv[0]
        , v = nv[1]
        ;
      if (Attrs[n].datatype === 'integer') v = parseInt(v);
      option[n] = v;
    });
    UserNumbers.forEach(function(item){
      var item = item.split(',')
        , rowid = item[0]
        , tjuc = item[1]
        , UserNumber = '86' + item[2]
        , subs = item[3] || ''
        , msg
        ;
      if (subs) {
        msg = new Submit(UserNumber, encode, cont.replace(/:n/, subs), option);
      } else {
        msg = new Submit(UserNumber, encode, cont, option);
      }
      msg.rowid = rowid;
      smsLogger('\n send at', new Date());
      smsLogger(msg);
      smsLogger(JSON.stringify(msg));
      sp.send(msg, function(res, req){
        smsLogger('\n\nrespond :');
        smsLogger('the result for %j is %d', res.header, res.Result);
        smsLogger('You can use oracle rowid %s to fill SMS id columns with %j', req.rowid, res.header);
      });
    });
  });
  msgStream.on('start', function(){
    console.log('message stream start.');
  });
  msgStream.on('finish', function(){
    console.log('message stream finish.');
    !quitFlag && process.nextTick(monitoring);
  });
}
// can start multiple oracle message stream broker job process for heavy load
monitoring();
monitoring();
monitoring();

function beforeExit(){
  quitFlag = true;
  console.log('executing beforeExit');
  dbc.call('sms_broker_h.quit', function(err, msg){
    console.log('call sms_broker_h.quit ok');
    // console.log(err, msg);
    console.log('after quit alert has been sent, wait broker to finish the current message making loop before process.exit()');
    setTimeout(function(){
      process.exit();
    }, 3000);
  });
}

process.on('SIGTERM', beforeExit); // kill or kill -15
process.on('SIGINT', beforeExit); // Ctrl-C
process.on('SIGQUIT', beforeExit); // press quit7
process.on('SIGTSTP', beforeExit);
process.on('SIGHUP', beforeExit); // when logout
process.on('SIGKILL', beforeExit); // kill -9

process.on('exit', function(){
  console.log('To be exit.');
});