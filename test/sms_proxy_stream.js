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

function fixTime(params){
  params.cmdTime = params.cmdTime.toString();
  if (params.cmdTime.length < 10) {
    params.cmdTime = '0' + params.cmdTime;
  }
}

sp.on('request', function(req){
  if (req instanceof SGIP.msgReport.Class) {
    console.log('\nReport:');
    var params = {
      srcNodeID : req.srcNodeID,
      cmdTime : req.cmdTime,
      cmdSeq : req.cmdSeq,
      UserNumber : req.UserNumber,
      State : req.State,
      ErrCode : req.ErrCode
    };
    fixTime(params);
    console.log(params);
    dbc.call('sms_sts_h.report', params, function(err, msg){
      err && console.warn('call sms_sts_h.smg_back for %j error :%s \n %s', params, err, msg);
    });
  } else if (req instanceof SGIP.msgDeliver.Class) {
    console.log('\nDeliver:');
  } else {
    console.log('\nUnknown Cmd Type:');
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
      smsLogger(cont.split('\n')[0] + ' ...', subs);

      dbc.call('sms_sts_h.sp_back', {sts : 'Y', rid : rowid}, function(err, msg){
        err && console.warn('call sms_sts_h.sp_back for rid=%s error : %s \n %s', rowid, err, msg);
      });

      sp.send(msg, function(res, req){
        smsLogger('\n\nrespond :');
        smsLogger('the result for %j is %d', res.header, res.Result);
        smsLogger('You can use oracle rowid %s to fill SMS id columns with %j', req.rowid, res.header);

        var params = res.header;
        fixTime(params);
        params.rid = rowid;
        params.Result = res.Result;
        console.log(params);
        dbc.call('sms_sts_h.smg_back', params, function(err, msg){
          err && console.warn('call sms_sts_h.smg_back for rid=%s error :%s \n %s', rowid, err, msg);
        });
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

Noradle.gracefulExit(function(){
  quitFlag = true;
  console.log('executing beforeExit');
  dbc.call('sms_broker_h.quit', function(err, msg){
    console.log('call sms_broker_h.quit ok');
    // console.log(err, msg);
    console.log('after quit alert has been sent, wait broker to finish the current message making loop before process.exit()');
    setTimeout(function(){
      process.exit(1);
    }, 3000);
  });
});