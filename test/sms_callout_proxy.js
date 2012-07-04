/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-26
 * Time: 上午10:32
 */
var SGIP = require('../../sms/node_sms')
  , SP = SGIP.nodeSP.Class
  , Submit = SGIP.msgSubmit.Class
  , Attrs = SGIP.AttrCfg
  , DCOWorkerProxy = require('../lib/dco_proxy.js')
  ;

var sp = new SP('202.99.87.201', 8801, 'dialbook', 'dialbooktest', 8801, '', 'dialbook', 'dialbooktest');

sp.on('request', function(req){
  if (req instanceof SGIP.msgReport.Class) {
    console.log('\nReport:');
  } else if (req instanceof SGIP.msgDeliver.Class) {
    console.log('\nDeliver:');
  }
  console.log(req);
});

DCOWorkerProxy.createServer(sendOneSimple).listen(1526);

function SimpleSmsSubmit(req){
  var lines = req.content.toString('utf8').split('\n');
  this.smg = lines.shift();
  this.target = lines.shift();
  this.content = lines.join('\n');
}

function sendOneSimple(dcoReq, dcoRes){
  var req = new SimpleSmsSubmit(dcoReq);
  var submit = new Submit(req.target, 8, req.content, {"SPNumber" : '106550224003'});
  console.log('\nSGIP request send:');
  sp.send(submit, function(sgipRes, sgipReq){
    console.log('\nSGIP respond :');
    console.log('the result for %j is %d', sgipRes.header, sgipRes.Result);
    console.log(sgipReq);
    if (dcoRes) {
      setTimeout(function(){
        dcoRes.end(req.content.split('\n')[0] + '... sent to ' + req.target + ' is completed.\n');
      }, 1000);
    }
  });
}

function sendBulkWithReport(req, resp){
  var lines = req.content.split('\n')
    , rowid = lines.shift()
    , cont = lines.shift()
    , encode = parseInt(lines.shift() || '0')
    , srcenc = lines.shift()
    , UserCount = lines.shift()
    , UserNumbers = lines.splice(0, UserCount)
    , option = {"SPNumber" : '10655022400312345678', "ReportFlag" : 2}
    ;
  if (srcenc === 'hex') {
    cont = new Buffer(cont, 'hex');
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
    var pair = item.split(',')
      , UserNumber = '86' + pair.shift()
      , subs = pair[0] || ''
      , msg
      ;
    if (subs) {
      msg = new Submit(UserNumber, encode, cont.replace(/:1/, subs), option);
    } else {
      msg = new Submit(UserNumber, encode, cont, option);
    }
    msg.rowid = rowid;
    console.log('\n send at', new Date());
    console.log(msg);
    console.log(JSON.stringify(msg));
    sp.send(msg, function(res, req){
      console.log('\n\nrespond :');
      console.log('the result for %j is %d', res.header, res.Result);
      console.log('You can use oracle rowid %s to fill SMS id columns with %j', req.rowid, res.header);
    });
  });
}