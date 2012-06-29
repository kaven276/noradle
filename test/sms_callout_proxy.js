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
  , net = require('net')
  , StreamSpliter = require('../lib/StreamSpliter.js').Class
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

var server = net.createServer(function(extHubSock){
  console.log('connect from ext_hub');
  var spliter = new StreamSpliter(extHubSock, 'readInt32BE');
  spliter.on('message', function onMessage(req){
    console.log('message length is ', req.length);
    sendOneSimple(req.slice(8).toString('utf8'));
  });
});

server.listen(1526);

function sendOneSimple(req){
  var lines = req.split('\n');
  var smg = lines.shift();
  var target = lines.shift();
  var content = lines.join('\n');
  var msg = new Submit(target, 8, content, {"SPNumber" : '106550224003'});
  console.log(msg);
  sp.send(msg, function(res, req){
    console.log('\n\nrespond :');
    console.log('the result for %j is %d', res.header, res.Result);
    console.log('You can use oracle rowid %s to fill SMS id columns with %j', req.rowid, res.header);
  });
}

function send(PDU){
  var lines = PDU.split('\n')
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