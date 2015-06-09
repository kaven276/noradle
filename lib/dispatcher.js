/**
 * Created by cuccpkfs on 15-5-18.
 * hold oracle reversed connections
 * oSlotID :
 * cSlotID : local to one client connection
 * client[cseq].reqs[cSlotID] = { oSlotID: number, buf: frames }
 * oraSlots[oSlotID].cSeq = cseq
 */

var net = require('net')
  , C = require('./constant.js')
  , debug = require('debug')('noradle:dispatcher')
  , frame = require('./util/frame.js')
  , _ = require('underscore')
  ;

var gcseq = 0
  , cseq = 0
  , marker = (new Buffer(4)).writeInt32BE(197610262, 0)
  ;

/*

 */
var queue = []
  ;

/*
 when a busy slot is going to quit,
 set flag to 0x01 for quitting,
 unset to 0x00 when quit or new slot added.
 when dispatcher determined a slot to quit,
 when the slot is free, just quit it
 when the slot is busy, set flag to quitting state,
 when busy request is finished, dispatcher will not recycle the slot to free slot list,
 and send quit signal to oracle process.
 */
var slotsFlag = new Buffer(1024);
slotsFlag.fill(0);


var client_cfgs = {
  'test' : {
    min_concurrency : 3,
    max_concurrency : 5,
    passwd : 'test'
  }
};


function Client(c, cSeq, cfg){
  this.socket = c;
  this.cSlots = new Array(1024);
  this.min_concurrency = cfg.min_concurrency;
  this.max_concurrency = cfg.max_concurrency;
  this.cur_concurrency = cfg.min_concurrency;
  var cSlots = this.cSlots = new Array(1024);
  for (var i = 0; i < 1000; i++) {
    cSlots[i] = {};
  }
}
var clients = {};

function authenticate(bufAuth){
  var auth = JSON.parse(bufAuth.toString());
  debug(auth);
  var cfg = client_cfgs[auth.cid];
  if (cfg && cfg.passwd === auth.passwd) {
    debug('client cid/passwd pass %j', cfg);
    return cfg;
  }
  debug('client cid/passwd error');
  return false;
}

// for accept front end request
// may accept from different front nodejs connection request
exports.server4node = net.createServer({allowHalfOpen : true}, function(c){
  var cseq = ++gcseq
    , cfg
    , client
    , authenticated = false
    ;

  if (cseq === 65536) {
    gcseq = 0;
    cseq = ++gcseq;
  }

  debug('node(%d) connected', cseq);

  frame.wrapFrameStream(c, 197610262, 197610263, function(head, cSlotID, type, flag, len, body){

    if (!authenticated) {

      cfg = authenticate(body);

      if (!cfg) {
        c.end();
        return;
      }

      authenticated = true;
      clients[cseq] = new Client(c, cseq, cfg);

      // give client free slots
      client = clients[cseq];
      frame.writeFrame(c, 0, C.SET_CONCURRENCY, 0, JSON.stringify(client.cur_concurrency));
      debug('write set_concurrency to %d', client.cur_concurrency);
      return;
    }

    if (cSlotID === 0) {
      req = JSON.parse(body);
      switch (type) {
        case 0:
          // authentication, check clientid, passcode
          break;
        case 1:
          // tell pending queue length
          break;
        case 255:
        // graceful quit
        default:
          ;
      }
      return;
    }

    // it's for normal request frame
    var req = client.cSlots[cSlotID]
      , oSlotID
      ;

    if (type === 0) {
      req = client.cSlots[cSlotID] = {};
      // for the first frame of a request
      if (freeOraSlotIDs.length > 0) {
        oSlotID = freeOraSlotIDs.shift();
        req.oSlotID = oSlotID;
        oraSessions[oSlotID].cSeq = cseq;
        oraSessions[oSlotID].cSlotID = cSlotID;
        oraSockets[oSlotID].write(head);
        body && oraSockets[oSlotID].write(body);
        debug('head frame use slot(%d)', oSlotID);
      } else {
        // init buf, add to queue
        req.buf = [head, body];
        queue.push([cseq, cSlotID]);
        debug('head frame no free slot');
      }
    } else {
      // for the successive frames of a request
      oSlotID = req.oSlotID;
      if (oSlotID) {
        oraSockets[oSlotID].write(head);
        body && oraSockets[oSlotID].write(body);
        debug('successive frame use bound slot(%d)', oSlotID);
      } else {
        req.buf.push(head);
        body && req.buf.push(body);
        debug('successive frame add to buf, wait oslot, %j', req.buf);
      }
    }

  });

  c.on('end', function(){
    debug('node(%d) disconnected', cseq);
  });

  c.on('error', function(err){
    console.error(err, cseq);
  })
})
;

var reservedSlotCount = 1000
  , oraSlots = new Array(reservedSlotCount)
  , oraSessions = new Array(reservedSlotCount)
  , oraSockets = new Array(reservedSlotCount)
  , freeOraSlotIDs = []
  , gConnSeq = 0
  ;

function Session(oSlotID, body){

  var session = {
    sid : body.readInt32BE(4),
    serial : body.readInt32BE(8),
    spid : body.readInt32BE(12),
    age : body.readInt32BE(16),
    reqs : body.readInt32BE(20)
  };

  var dbNames = body.slice(24).toString().split('/');
  var db = {
    name : dbNames[0],
    domain : dbNames[1],
    unique : dbNames[2],
    role : dbNames[3],
    inst : body.readInt32BE(0)
  };

  // fixed properties
  this.slotID = oSlotID;
  this.head = body;
  this.session = session;
  this.db = db;

  // dynamic properties
  this.cSeq = null;
  this.quitting = false;
}


function afterNewAvailableOSlot(oSlotID, isNew){
  debug('queue %j', queue);
  var w = queue.shift();
  if (w) {
    // use slotID to send w request
    var cSeq = w[0]
      , cSlotID = w[1]
      , client = clients[cSeq]
      , req = client.cSlots[cSlotID]
      , buf = req.buf
      ;
    debug('unshift queue item cseq=%d, cSlotID=%d, req=%j', cSeq, cSlotID, req);
    oraSockets[oSlotID].write(Buffer.concat(buf));
    delete req.buf;
    req.oSlotID = oSlotID;
    oraSessions[oSlotID].cSeq = cSeq;
    debug('switch %j to use oSlot(%d)', w, oSlotID);
  } else {
    if (isNew) {
      freeOraSlotIDs.push(oSlotID);
    } else {
      if (oraSessions[oSlotID].quitting) {
        signalQuit(oraSockets[oSlotID]);
      } else {
        freeOraSlotIDs.unshift(oSlotID);
      }
    }
  }
}

function signalQuit(c){
  frame.writeFrame(c, 0, C.HEAD_FRAME, 0, (new Buffer(['QUIT', ''].join('\r\n')) + '\r\n\r\n\r\n'));
  frame.writeFrame(c, 0, C.END_FRAME, 0, null);
}

function signalKeepAlive(c){
  frame.writeFrame(c, 0, C.HEAD_FRAME, 0, (new Buffer(['KEEPALIVE', '', 'keepAliveInterval', keepAliveInterval, '', '', ''].join('\r\n')) ));
  frame.writeFrame(c, 0, C.END_FRAME, 0, null);
}

// for oracle reverse connection
exports.server4oracle = net.createServer(function(c){
  var oSlotID, connSeq = ++gConnSeq, registered = false;
  debug('oracle seq(%d) connected', connSeq);

  frame.wrapFrameStream(c, 197610262, 197610261, function(head, cSlotID, type, flag, len, body){

    if (!registered) {
      registered = true;
      oSlotID = cSlotID;
      oraSessions[oSlotID] = new Session(oSlotID, body);
      oraSockets[oSlotID] = c;
      signalKeepAlive(c);
      debug('oracle seq(%s) oSlot(%s) slot add, freeList=%j', connSeq, oSlotID, freeOraSlotIDs);
      // todo: when a new oraSock is add, run a queued request immediately or push it to freeSlots
      afterNewAvailableOSlot(oSlotID, true);
    } else if (cSlotID === 0) {
      // control frame from oracle
      if (type === C.RO_QUIT) {
        // oracle want to quit, if oSlot is free then quit, otherwise make oSlot is quitting, quit when release
        oraSessions[oSlotID].quitting = true;
        var index = freeOraSlotIDs.indexOf(oSlotID);
        if (index >= 0) {
          freeOraSlotIDs.splice(index, 1);
          signalQuit(c);
        }
      }
    } else {
      // redirect frame to the right client socket untouched
      debug('from oracle: cSlotID=%d, cseq=%d, clients=%j', cSlotID, oraSessions[oSlotID].cSeq, Object.keys(clients));
      var cliSock = clients[oraSessions[oSlotID].cSeq].socket;
      cliSock.write(head);
      body && cliSock.write(body);
      if (type === C.END_FRAME) {
        // reclaim oraSock for other use
        debug('oSlot is freed');
        afterNewAvailableOSlot(oSlotID, false);
      }
    }
  });

  c.on('end', function(){
    debug('oracle seq(%s) oSlot(%s) disconnected', connSeq, oSlotID);
    // find free list and remove from free list
    var pos = freeOraSlotIDs.indexOf(oSlotID);
    if (pos >= 0) {
      // if in free list, just remove from free list
      freeOraSlotIDs.splice(pos, 1);
      debug('oracle seq(%s) oSlot(%s) slot removed, freeList=%j', connSeq, oSlotID, freeOraSlotIDs);
    } else {
      // if in busy serving a client request, raise a error for the req
      var oSlot = oraSessions[oSlotID];
      if (!oSlot.quitting) {
        debug('oSlot=%j', oSlot);
        debug('oracle seq(%s) oSlot(%s) slot not in freeList.freeList(%j) cSlotid(%d)', connSeq, oSlotID, freeOraSlotIDs, oSlot.cSlotID);
        //frame.writeFrame(clients[oSlot.cSeq].socket, oSlot.cSlotID, C.ERROR_FRAME, 0);
      }
    }
    oraSessions[oSlotID] = null;
    oraSockets[oSlotID] = null;
  });
});

/**
 * for keep-alive to oracle
 * dispatcher is usually deployed with oracle database at the same server or same LAN,
 * so normally keep-alive is not required
 * but when they are connected throuth NAT, keep-alive is required to detect a NAT state lost.
 * OPS will quit after idle_timeout seconds
 * dispatcher will treat oSlot as lost connection when keep-alive request have no reply
 * oracle will send keep-alive frame
 * every n seconds, dispatcher send free oSlot a keep-alive frame
 * OPS wait over n seconds, no frame is arrived, OPS detect lost connection, then re-connect
 * n value is send with keep-alive setting frame from dispatcher to OPS when first connected or value is changed
 * if n+3 s, no pong frame received, dispatcher detect lost connection, then release oSlot
 * If firewall suddenly restart, dispatcher/OPS can both detect lost connection
 */
var keepAliveInterval = 280;
setInterval(function(){
  freeOraSlotIDs.forEach(function(oSlotID){
    signalKeepAlive(oraSockets[oSlotID]);
  });
}, keepAliveInterval * 1000);

var http = require('http')
  ;
var monitor = http.createServer(function(req, res){
  res.writeHead(200, {
    'content-type' : 'application/json'
  });
  var pool = {};
  for (n in oraSessions) {
    var slot = oraSessions[n];
    if (slot) {
      pool[n] = {
        slotID : n,
        db : slot.db,
        active : slot.active,
        session : slot.session
      }
    }
  }
  res.end(JSON.stringify(pool, null, 2));
});
monitor.listen(8888);

exports.listenOracle = function(port){
  pool.listen(port, function(){
    debug('listening to oracle at port:%d', port);
  });
};

exports.listenClient = function(port){
  server.listen(port, function(){
    debug('listening to client at port:%d ', port);
  });
};

exports.start = function(oraclePort, nodePorts){
  exports.server4oracle.listen(oraclePort, function(){
    debug('listening to oracle at port:%d', oraclePort);
  });
  nodePorts.forEach(function(nodePort){
    exports.server4node.listen(nodePort, function(){
      debug('listening to node at port:%d', nodePort);
    });
  });
};

exports.startShell = function(){
  var oraclePort = process.argv[2]
    , nodePorts = process.argv.slice(3)
    ;
  if (nodePorts.length === 0) {
    console.error('usage: inHub.sh oraclePort nodePorts...');
    return;
  }
  exports.start(oraclePort, nodePorts);
};

// for direct script file execution
(function(){
  if ((process.argv[1] !== __filename)) return;
  var oraclePort = 9008;
  exports.server4oracle.listen(oraclePort, function(){
    debug('listening to oracle at port:%d', oraclePort);
  });
  var nodePort = 9009;
  exports.server4node.listen(nodePort, function(){
    debug('listening to node at port:%d', nodePort);
  });
  //require(require('path').join(__dirname, '..')).inHub.startShell();
})();
