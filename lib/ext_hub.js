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

function TraceBack(oraSock, reqSeq){
  this.oraSock = oraSock;
  this.reqSeq = reqSeq;
}
var server = net.createServer(function(oraSock){
  console.log('oracle connected');
  var sid, serial, rseq;
  // oraSock.setEncoding('raw');
  oraSock.once('data', function(data){
    console.log(data);
    sid = data.readInt32BE(0);
    serial = data.readInt32BE(4);
    rseq = data.readInt32BE(8);
    oraSocks[sid] = oraSock;
    oraSock.sid = sid;
    oraSock.serial = serial;
    oraSock.rseq = rseq;
    console.log(data, sid, serial);
    var spliter = new StreamSpliter(oraSock, 'readInt32BE');
    spliter.on('message', onMessage);
  });
  function onMessage(msg){
    console.log('length = %d, proxy id = %d, rseq = %d', msg.length, msg.readUInt16BE(4), rseq + 1);
    var proxyID = msg.readUInt16BE(4)
      , wpSock = wpSocks[proxyID]
      ;
    ++rseq;
    ++wpSock.reqSeq;
    if (msg.readInt32BE(0) > 0) {
      wpSock.reqLog[wpSock.reqSeq] = new TraceBack(oraSock, rseq);
    }
    msg.writeUInt16BE(wpSock.reqSeq, 4);
    wpSock.write(msg);
  }
});
server.listen(1524);

// pre-connect to all worker proxy
var wps = require('../worker_proxy_cfg.js')
  , wpSocks = [];
wps.forEach(function(wp, i){
  if (!wp) return;
  var hostp = wp[0].split(':')
    , wpSock = wpSocks[i] = new net.Socket()
    ;
  wpSock.connect(hostp[1] || '1520', hostp[0], function(){
    console.log('%j connected', wp);
    var spliter = new StreamSpliter(wpSock, 'readInt32BE');
    spliter.on('message', function onMessage(proxyResp){
      console.log('message length is ', proxyResp.length);
      console.log('proxyResp before', proxyResp);
      var proxySeq = proxyResp.readUInt16BE(4)
        , traceBack = wpSock.reqLog[proxySeq]
        , oraSock = traceBack.oraSock
        , oraReqSeq = traceBack.reqSeq
        ;
      proxyResp.writeUInt16BE(oraReqSeq, 4);
      oraSock.write(proxyResp);
      console.log('proxyResp after', proxyResp);
    });
  });
  wpSock.reqSeq = 0;
  wpSock.reqLog = [];
});