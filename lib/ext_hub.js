/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-25
 * Time: 上午10:01
 */

var net = require('net')
  , oraSocks = []
  , StreamSpliter = require('./StreamSpliter').Class
  ;

var server = net.createServer(function(oraSock){
  console.log('oracle connected');
  var sid, serial;
  // oraSock.setEncoding('raw');
  oraSock.once('data', function(data){
    console.log(data);
    sid = data.readInt32BE(0);
    serial = data.readInt32BE(4);
    oraSocks[sid] = oraSock;
    oraSock.sid = sid;
    oraSock.serial = serial;
    console.log(data, sid, serial);
    var spliter = new StreamSpliter(oraSock, 'readInt32BE');
    spliter.on('message', onMessage);
  });
  function onMessage(msg){
    console.log('message length is ', msg.length);
    console.log(msg);
    oraSock.emit('request', msg.readInt32BE(4), msg);
  }

  oraSock.on('request', function(proxyID, msg){
    console.log('proxy id = %d', proxyID);
    wpSocks[proxyID].write(msg);
  });
});
server.listen(1524);

// pre-connect to all worker proxy
var wps = require('../worker_proxy_cfg.js')
  , wpSocks = [];
wps.forEach(function(wp, i){
  if (!wp) return;
  var hostp = wp[0].split(':')
    ;
  wpSocks[i] = new net.Socket();
  wpSocks[i].connect(hostp[1] || '1520', hostp[0], function(){
    console.log('%j connected', wp);
  });
});