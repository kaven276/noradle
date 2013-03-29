/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-25
 * Time: 上午10:01
 */

var net = require('net')
  , StreamSpliter = require('./StreamSpliter').Class
  , oraSocks = {}
  , wpSocks = []
  , utl = require('./util.js')
  , logConnWP = utl.dummy
  , logConnOra = console.log
  , logPDU = console.log
  , pendingReturn = 0
  ;

function gracefulQuit(){
  console.log('ext-hub is exiting !');
  console.log('current connection is %d', server.connections);

  if (false) {
    for (var asid in oraSocks) {
      var sock = oraSocks[asid].socket;
      sock.end();
      console.log('send end signal to oracle connection for asid=%d', asid);
    }
  }

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


function OraSock(oraSock, data){
  this.socket = oraSock;
  this.sid = data.readInt32BE(4);
  this.serial = data.readInt32BE(8);
  this.asid = data.readUInt32BE(12);
}

var server = net.createServer(function(oraSock){
  var _rec, asid;
  logConnOra('oracle connected');

  oraSock.once('data', onHandshake);

  oraSock.on('close', function(){
    if (asid) {
      delete oraSocks[asid];
    }
    logConnOra('connection closed, now have %d', server.connections);
  });

  function onHandshake(data){

    try {
      var ptoken = data.readInt32BE(0);
    } catch (e) {
      ptoken = -1;
    }
    if (ptoken !== 197610262) {
      console.warn('EXT-HUB: none oracle connection attempt found');
      oraSock.end();
      oraSock.destroy();
      return;
    }

    asid = data.readUInt32BE(12);
    _rec = oraSocks[asid] = new OraSock(oraSock, data);

    logConnOra('oracle connected(%d,%d,%d)', _rec.asid, _rec.sid, _rec.serial);
    new StreamSpliter(oraSock, 'readInt32BE', onOracleRequest);

    if (data.length !== 16) {
      logConnOra('first chunk is not 16 bytes length.');
      oraSock.emit('data', data.slice(16));
    }
  }

  function onOracleRequest(oraReq){
    var proxyID = oraReq.readInt32BE(4)
      , wpw = wpSocks[proxyID]
      ;
    logPDU('> ora(%d,%d,%d,%d) - wp(%d)', _rec.asid, _rec.sid, _rec.serial, oraReq.readInt32BE(8), proxyID);

    if (!wpw) {
      console.warn('%s, proxy %d is not exists', new Date(), proxyID);
      return;
    }
    /* replace proxyID field with oraSeq */
    oraReq.writeInt32BE(asid, 4);
    (wpw.sts === 'opened') ? wpw.wpSock.write(oraReq) : wpw.queue.push(oraReq);
  }
});

/**
 * A worker proxy client wrapper class
 * @constructor
 * @param {number} id worker proxy client socket slot, start at 0
 * @param {string }hostp worker proxy server address, format as "host:port"
 * @param {string} desc worker proxy description.
 */

function WPWrapper(id, hostp, desc){
  var wpw = this;
  var wpSock = this.wpSock = new net.Socket({allowHalfOpen : true});
  this.id = id;
  this.hostp = hostp.split(':');
  this.desc = desc;
  this.sts = 'close';
  this.queue = [];

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
    var ptoken = new Buffer(4);
    ptoken.writeInt32BE(197610263, 0);
    wpSock.write(ptoken);
    logConnWP('Connect to proxy NO.%d(%s) is ok', wpw.id, wpw.desc);
    wpw.queue.forEach(function(PDU){
      wpSock.write(PDU);
    });
    wpw.queue = [];
  });

  new StreamSpliter(wpSock, 'readInt32BE', onWorkerProxyReply);

  function onWorkerProxyReply(proxyResp){
    var len = proxyResp.readInt32BE(0);
    if (len === 12) {
      wpw.setStatus('exiting', 'wp said he will quit');
      wpSock.end();
      return;
    }

    var asid = proxyResp.readInt32BE(4)
      , rec = oraSocks[asid]
      , oraSeq = proxyResp.readInt32BE(8)
      ;
    if (!rec) {
      console.warn('can not find the sending oracle connection, reply will lose');
      return;
    }

    rec.socket.write(proxyResp);
    logPDU('< ora(%d,%d,%d,%d) - wp(%d)', rec.asid, rec.sid, rec.serial, oraSeq, wpw.id);
  }
}

WPWrapper.prototype.connect = function(){
  this.wpSock.connect(this.hostp[1], this.hostp[0]);
  this.setStatus('opening', 'attempt to connect worker proxy');
};

WPWrapper.prototype.setStatus = function(sts, env){
  logConnWP('wpSock %d sts=%s @ %s :-> %s', this.id, sts, env || '?', this.desc);
  this.sts = sts;
};

exports.addWorkerProxy = function(slot, addr, desc){
  if (wpSocks[slot]) {
    console.warn('The NO.%d slot is already used by %s', wpSocks[slot].desc);
    return;
  }
  var wpw = new WPWrapper(slot, addr, desc);
  wpSocks[slot] = wpw;
  wpw.connect();
  console.log('set NO.%d worker proxy : %s', slot, desc);
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
