/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-25
 * Time: 上午10:01
 */

var net = require('net')
  , StreamSpliter = require('./StreamSpliter').Class
  , oraSocks = []
  , wpSocks = []
  , utl = require('./util.js')
  , logConnWP = utl.dummy
  , logConnOra = console.log
  , logPDU = console.log
  , logSeqQ = utl.dummy
  , pendingReturn = 0
  , debug = false
  ;

function TraceBack(oraSock, oraSeq){
  this.oraSock = oraSock;
  this.oraSeq = oraSeq;
}

function gracefulQuit(){
  console.log('ext-hub is exiting !');
  console.log('current connection is %d', server.connections);

  function checkQuit(){
    if (pendingReturn === 0) {
      process.exit(2);
    }
  }

  server.on('close', function(){
    console.log('ext-hub server is closed !');
    process.exit(1);
  });
  server.close();
  // at this time, oracle can read rpc response, new connection is forbidden
  // send using existing connection will read all response to PV and then close and reconnect

  // must checkQuit later, if check now, some request may be send to ext-hub but event handler may not execute
  // this case, the request will be lost, so delay 1s for new requests(between now and quit alert) events to hande
  setInterval(checkQuit, 1000);
}

// todo: should let oracle to send quit alert first
utl.gracefulExit(gracefulQuit);

var server = net.createServer(function(oraSock){
  logConnOra('oracle connected');

  var onDataCount = 0;
  oraSock.on('data', function(data){
    logConnOra('data arrived from oracle NO.%d len=%d', ++onDataCount, data.length);
  });

  var sid, serial;
  oraSock.once('data', onHandshake);

  oraSock.on('close', function(){
    logConnOra('connection closed, now have %d', server.connections);
  });

  function onHandshake(data){
    oraSock.sid = sid = data.readInt32BE(0);
    oraSock.serial = serial = data.readInt32BE(4);
    oraSock.oraSeq = data.readInt32BE(8);
    oraSocks[sid] = oraSock;
    logConnOra(data, sid, serial);
    logConnOra('oracle connected sid = %d, serial = %d, initial oraSeq = %d', sid, serial, oraSock.oraSeq);
    new StreamSpliter(oraSock, 'readInt32BE', onOracleRequest);

    if (oraSock.oraSeq < 0) {
      gracefulQuit();
      oraSock.write('exiting\n');
      return;
    }

    if (data.length !== 12) {
      logConnOra('first chunk is not 12 bytes length.');
      oraSock.emit('data', data.slice(12));
    }
  }

  function onOracleRequest(oraReq){
    var proxyID = oraReq.readUInt16BE(4)
      , wpw = wpSocks[proxyID]
      , oraSeq = oraSock.oraSeq++
      ;
    wpw.whenHaveFreeTraceBackID(oraReq.readInt32BE(0) > 0, function(rpcSeq){
      if (rpcSeq === 0) {
        // for no reply or no rpc requests
        oraReq.writeUInt16BE(0, 4);
      } else {
        oraReq.writeUInt16BE(rpcSeq, 4);
        logPDU('> ora(%d,%d,%d) - wp(%d,%d)', sid, serial, oraSeq, proxyID, rpcSeq);
        wpw.rpcLog[rpcSeq] = new TraceBack(oraSock, oraSeq);
      }
      (wpw.sts === 'opened') ? wpw.wpSock.write(oraReq) : wpw.queue.push(oraReq);
    });
  }
});


function WPWrapper(wpSock, id, hostp, maxPendingRpc, desc){
  var wpw = this;
  this.desc = desc;
  this.wpSock = wpSock;
  this.hostp = hostp.split(':');
  this.id = id;
  this.sts = 'close';
  this.queue = [];
  this.rpcLog = [];
  this.freeList = utl.makeArray(maxPendingRpc || 256);
  this.freeList.shift();
  this.noRpcSeqQueue = [];

  wpSock.on('end', function(){
    // worker proxy real closed
    wpw.setStatus('close', 'on end');
  });

  wpSock.on('error', function(){
    // worker proxy connect failed
    logConnWP(wpw.sts === 'opening' ? 'connect to wp %d(%s) failed' : 'opened connection %d has error', wpw.id, wpw.desc);
    wpw.setStatus('close', 'on error');
  });

  wpSock.on('connect', function(){
    wpw.setStatus('opened', 'TCP socket connected');
    logConnWP('Connect to proxy NO.%d(%s) is ok', wpw.id, wpw.desc);
    wpw.queue.forEach(function(PDU){
      wpSock.write(PDU);
    });
  });

  new StreamSpliter(wpSock, 'readInt32BE', onWorkerProxyReply);

  function onWorkerProxyReply(proxyResp){
    var len = proxyResp.readInt32BE(0)
      , rpcSeq = proxyResp.readUInt16BE(4)
      ;
    if (len === 6) {
      wpw.setStatus('exiting', 'wp said he will quit');
      wpSock.end();
      return;
    }
    // logPDU('reply for proxySeq=%d, %s', proxySeq, proxyResp.slice(0, 6).toString('hex'));
    var traceBack = wpw.rpcLog[rpcSeq]
      , oraSock = traceBack.oraSock
      , oraSeq = traceBack.oraSeq
      ;
    if (!traceBack) console.warn('proxSeq:%d have no traceback', rpcSeq);
    wpw.recycleRpcSeq(rpcSeq);
    proxyResp.writeUInt16BE(oraSeq, 4);
    oraSock.write(proxyResp);
    logPDU('< ora(%d,%d,%d) - wp(%d,%d)', oraSock.sid, oraSock.serial, oraSeq, wpw.id, rpcSeq);
  }
}

WPWrapper.prototype.connect = function(){
  this.wpSock.connect(this.hostp[1] || '1520', this.hostp[0]);
  this.setStatus('opening', 'attempt to connect worker proxy');
};

WPWrapper.prototype.setStatus = function(sts, env){
  logConnWP('wpSock %d sts=%s @ %s :-> %s', this.id, sts, env || '?', this.desc);
  this.sts = sts;
};

WPWrapper.prototype.whenHaveFreeTraceBackID = function(isRPC, callback){
  if (!isRPC) {
    callback(0);
  } else {
    pendingReturn++;
    var rpcSeq = this.freeList.shift();
    if (rpcSeq === undefined) {
      this.noRpcSeqQueue.push(callback);
      logSeqQ('no free rpc trace back sequence available.');
    } else {
      callback(rpcSeq);
    }
  }
};

WPWrapper.prototype.recycleRpcSeq = function(rpcSeq){
  pendingReturn--;
  var callback = this.noRpcSeqQueue.shift();
  if (callback) {
    callback(rpcSeq);
    logSeqQ('new free rpc trace back sequence available, and used for queued request.');
  } else {
    delete this.rpcLog[rpcSeq];
    this.freeList.push(rpcSeq);
    // logSeqQ('new free rpc trace back sequence available, just recycled.');
  }
};

var curID = 0;
exports.addWorkerProxy = function(addr, desc, maxPendingRpc){
  var wpw = new WPWrapper(new net.Socket({allowHalfOpen : true}), curID, addr, maxPendingRpc, desc);
  wpSocks[curID] = wpw;
  wpw.connect();
  curID++;
};
exports.run = function(port){
  server.listen(parseInt(port || 1523));
};
/**
 * periodically check if currently unavailable target worker proxies is available again
 */
setInterval(function(){
  wpSocks.forEach(function(wpw){
    if (wpw.sts === 'close') {
      wpw.connect();
    }
  });
}, 3000);
