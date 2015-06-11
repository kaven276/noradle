/**
 * Created by cuccpkfs on 15-5-12.
 * dispatch client request to oracle process
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

var client_cfgs = {
  'test' : {
    min_concurrency : 3,
    max_concurrency : 5,
    passwd : 'test'
  }
};


function Client(c, cseq){
  this.socket = c;
  debug('new client freeList %j', freeOraSlotIDs);
  var slotID = freeOraSlotIDs.shift();
  if (slotID) {
    this.slots = [slotID];
    oraSlots[slotID].cseq = cseq;
    frame.writeFrame(c, 0, C.ADD_SLOT, 0, new Buffer(JSON.stringify([slotID])));
  } else {
    this.slots = [];
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
    , authenticated = false
    , cid = 1
    ;

  debug('node(%d) connected', cseq);

  frame.wrapFrameStream(c, 197610262, 197610263, function(head, slotID, type, flag, len, body){

    if (!authenticated) {

      if (!authenticate(body)) {
        c.end();
        return;
      }

      authenticated = true;
      clients[cseq] = new Client(c, cseq);
      return;
    }

    if (slotID === 0) {
      req = JSON.parse(body);

      switch (type) {
        case 0:
          // authentication, check clientid, passcode
          authenticated = true;
          // give client free slots
          client = clients[cid];
          var slots = freeOraSlotIDs.splice(0, client.min_concurrency)
            , msgHead = new Buffer(8)
            , msgBody = JSON.stringify(slots)
            ;
          client.slots = client.slots.concat(slots);
          msgHead.writeUInt16BE(0, 0);
          msgHead.writeUInt8(1, 2); // for increase slot
          msgHead.writeUInt32BE(msgBody.length, 4);
          c.write(msgHead);
          c.write(msgBody);
          break;
        case 1:
          // tell pending queue length
          break;
        case 255:
        // graceful quit
        default:
          ;
      }
    } else {
      // it's for normal request frame
      // send it to oracle socket untouched
      if (type === 0) {
        // it's for request head, the 1st request frame
        // increase counter for this slot
      }
      var oraSock = oraSockets[slotID];
      oraSock.write(head);
      body && oraSock.write(body);
      debug('relay to oracle %j', slotID);
    }
  });

  c.on('end', function(){
    debug('node(%d) disconnected', cseq);
  });

  c.on('error', function(err){
    console.error(err, cseq);
  })
});


var reservedSlotCount = 1000
  , oraSlots = new Array(reservedSlotCount)
  , oraSockets = new Array(reservedSlotCount)
  , freeOraSlotIDs = []
  , gConnSeq = 0
  ;

function Slot(slotID, body){
  var dbNames = body.slice(24).toString().split('/');

  var db = {
    name : dbNames[0],
    domain : dbNames[1],
    unique : dbNames[2],
    role : dbNames[3],
    inst : body.readInt32BE(0)
  };

  var session = {
    sid : body.readInt32BE(4),
    serial : body.readInt32BE(8),
    spid : body.readInt32BE(12),
    age : body.readInt32BE(16),
    reqs : body.readInt32BE(20)
  };

  this.slotID = slotID;
  this.head = body;
  this.session = session;
  this.db = db;
  this.cseq = null;
  this.pendingRequest = null;
  this.pendingResponse = null;
  this.assined = false;
  this.active = false;
  this.quitting = false;
  debug(this);

  // when a new oraSock is add, try give it to one of the clients, or push onto the freelist
  for (var cseq in clients) {
    var client = clients[cseq];
    if (client.slots.length === 0) {
      this.cseq = cseq;
      client.slots.push(slotID);
      frame.writeFrame(client.socket, 0, C.ADD_SLOT, 0, new Buffer(JSON.stringify([slotID])));
      return;
    }
  }
  freeOraSlotIDs.push(slotID);
}

// for oracle reverse connection
exports.server4oracle = net.createServer(function(c){
  var sSlotID, connSeq = ++gConnSeq, registered = false;
  debug('oracle(%d) connected', connSeq);

  frame.wrapFrameStream(c, 197610262, 197610261, function(head, slotID, type, flag, len, body){

    if (!registered) {
      registered = true;
      sSlotID = slotID;
      oraSlots[slotID] = new Slot(slotID, body);
      oraSockets[slotID] = c;
      debug('oracle(%s,%s) slot add, freeList=%j', connSeq, slotID, freeOraSlotIDs);
    } else {
      // redirect frame to the right client socket untouched
      debug('slotID=%d, cseq=%d, clients=%j', slotID, oraSlots[slotID].cseq, Object.keys(clients));
      var cliSock = clients[oraSlots[slotID].cseq].socket;
      cliSock.write(head);
      body && cliSock.write(body);
    }
  });

  c.on('end', function(){
    debug('oracle(%d,%d) disconnected', sSlotID, connSeq);
    // find free list and remove from free list
    var cseq = oraSlots[sSlotID].cseq;
    if (cseq) {
      // tell client that hold the slot must not use that slot anymore
      var client = clients[cseq];
      debug('clients.slots = %j', clients.slots);
      client.slots.splice(_.indexOf(client.slots, sSlotID), 0);
      debug('clients.slots = %j', clients.slots);
      // remove slotID from client.slots;
      oraSlots[slotID].cseq = null;
      frame.writeFrame(c, 0, C.DEL_SLOT, 0, new Buffer(JSON.stringify([sSlotID])));
    }
    oraSlots[sSlotID] = null;
    oraSockets[sSlotID] = null;
    var pos = freeOraSlotIDs.indexOf(sSlotID);
    if (pos >= 0) {
      freeOraSlotIDs.splice(pos, 1);
      debug('oracle(%d,%d) slot removed, freeList=%j', connSeq, sSlotID, freeOraSlotIDs);
    } else {
      debug('oracle(%d,%d) slot not in freeList.freeList(%j)', connSeq, sSlotID, freeOraSlotIDs);
      // 应该将对应的 node socket 发送 tcp fin
      // 而且可能马上就会有新的 oracle 连接建立，取代原先的连接
      //
    }
  });
});

var http = require('http')
  ;
var monitor = http.createServer(function(req, res){
  res.writeHead(200, {
    'content-type' : 'application/json'
  });
  var pool = {};
  for (n in oraSlots) {
    var slot = oraSlots[n];
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
