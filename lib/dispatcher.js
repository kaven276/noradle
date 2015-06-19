/**
 * Created by kaven276@vip.sina.com on 15-5-18.
 * dispatcher is a frame switcher who provide dynamic virtual connection for client request and oracle response
 * design principle: simple, robust, stable long running
 *
 * usage:
 * require('noradle').dispatcher.start({
 * oracle_port: the port to listen for oracle reversed connection,
 * node_port: the port to listen for client connection,
 * keep_alive_interval: number of seconds to send keep_alive frame to oracle,
 * client_config: the path client configuration is located on
 * db: {
 *   ... as session db to check oracle connection is from right db
 * }
 *
 * or use command line
 * dispatcher --oracle_port=xxx --node_port=xxx keep_alive_interval=xxx client_config=xxx
 *
 * functions:
 * check and hold oracle reversed connections, keep-alive to oracle
 * authenticate and hold client connections
 * establish/destroy virtual connections from client to oracle process
 * assign concurrency to clients statically and dynamically
 * provide current/accumulative statistics
 *
 * variable explain:
 * oSlotID :
 * cSlotID : local to one client connection
 * client[cseq].reqs[cSlotID] = { oSlotID: number, buf: frames }
 * oraSlots[oSlotID].cSeq = cseq
 */

var net = require('net')
  , fs = require('fs')
  , dnode = require('dnode')
  , frame = require('./util/frame.js')
  , _ = require('underscore')
  , debug = require('debug')('noradle:dispatcher')
  , C = require('./constant.js')
  , queue = []
  , client_cfgs
  , clients = new Array(C.MAX_CLIENTS)
  , clientsHW = 0
  , oraSessions = new Array(C.ORA_MAX_SLOTS)
  , oraSessionsHW = 0
  , freeOraSlotIDs = []
  , gConnSeq = 0
  ;

function Client(c, cSeq, cid){
  this.socket = c;
  this.cSeq = cSeq;
  this.cid = cid;
  this.cSlots = new Array(C.CLI_MAX_SLOTS);
  var cfg = client_cfgs[cid];
  this.cur_concurrency = cfg.min_concurrency;
  this.cfg = cfg;
}

// todo : secure client authenticate
// may support dynamic client auth with database
// or use dynamic cfg file that can be updated at runtime
// then can be CHAP code later to protect password transfer
// dispatcher give a random code
// client send md5(passwd+random) back to dispatcher to test

function authenticate(bufAuth){
  var auth = JSON.parse(bufAuth.toString());
  debug(auth);
  var cfg = client_cfgs[auth.cid];
  if (cfg && cfg.passwd === auth.passwd) {
    debug('client cid/passwd pass %j', cfg);
    return auth.cid;
  }
  debug('client cid/passwd error');
  return false;
}

function bindOSlot(req, cseq, cSlotID, oSlotID){
  req.oSlotID = oSlotID;
  var oraSlot = oraSessions[oSlotID];
  oraSlot.cSeq = cseq;
  oraSlot.cSlotID = cSlotID;
}

exports.server4all = net.createServer({allowHalfOpen : true}, function(c){

  frame.wrapFrameStream(c, 197610262, mmChecker);

  function mmChecker(mm){
    switch (mm) {
      case 197610263:
        c.on('frame', serveClient(c));
        return true;
      case 197610261:
        c.on('frame', serveOracle(c));
        return true;
      case 197610264:
        c.removeAllListeners('readable');
        c.pipe(dnode(monServices)).pipe(c);
        return true;
      default:
        return false;
    }
  }
});

function findMinFreeCSeq(){
  for (var i = 0; i < clientsHW; i++) {
    if (!clients[i]) return i;
  }
  return clientsHW++;
}

// for accept front end request
// may accept from different front nodejs connection request
function serveClient(c){
  var cseq = findMinFreeCSeq()
    , client
    , authenticated = false
    ;

  debug('node(%d) connected', cseq);

  c.on('end', function(){
    debug('node(%d) disconnected', cseq);
    delete clients[cseq];
  });

  c.on('error', function(err){
    console.error('client socket error', err, cseq);
    clients[cseq] = undefined;
  });


  return function processClientFrame(head, cSlotID, type, flag, len, body){

    if (!authenticated) {
      if (!(cid = authenticate(body))) {
        //todo: may tell what's wrong to client
        c.end();
        return;
      }

      authenticated = true;
      client = clients[cseq] = new Client(c, cseq, cid);
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
    var req, oSlotID, oSock;

    if (type === C.HEAD_FRAME) {
      req = client.cSlots[cSlotID] = {};
      // for the first frame of a request
      if (freeOraSlotIDs.length > 0) {
        oSlotID = freeOraSlotIDs.shift();
        bindOSlot(req, cseq, cSlotID, oSlotID);
        oSock = oraSessions[oSlotID].socket;
        oSock.write(head);
        body && oSock.write(body);
        debug('head frame use slot(%d)', oSlotID);
      } else {
        // init buf, add to queue
        req.buf = [head, body];
        queue.push([cseq, cSlotID]);
        debug('head frame no free slot');
      }
    } else {
      req = client.cSlots[cSlotID]
      // for the successive frames of a request
      oSlotID = req.oSlotID;
      if (oSlotID) {
        oSock = oraSessions[oSlotID].socket;
        oSock.write(head);
        body && oSock.write(body);
        debug('successive frame use bound slot(%d)', oSlotID);
      } else {
        req.buf.push(head);
        body && req.buf.push(body);
        debug('successive frame add to buf, wait oslot, %j', req.buf);
      }
    }

  }
}

function Session(oSlotID, body, socket){

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
  this.socket = socket;

  // dynamic properties
  this.cSeq = null;
  this.cSlotID = null;
  this.quitting = false;

  if (oSlotID > oraSessionsHW) {
    oraSessionsHW = oSlotID;
  }
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
    oraSessions[oSlotID].socket.write(Buffer.concat(buf));
    delete req.buf;
    bindOSlot(req, cSeq, cSlotID, oSlotID);
    debug('switch %j to use oSlot(%d)', w, oSlotID);
  } else {
    if (isNew) {
      freeOraSlotIDs.push(oSlotID);
    } else {
      freeOraSlotIDs.unshift(oSlotID);
    }
  }
}

function signalOracleQuit(c){
  frame.writeFrame(c, 0, C.HEAD_FRAME, 0, (new Buffer(['QUIT', ''].join('\r\n')) + '\r\n\r\n\r\n'));
  frame.writeFrame(c, 0, C.END_FRAME, 0, null);
}

function signalOracleKeepAlive(c){
  frame.writeFrame(c, 0, C.HEAD_FRAME, 0, (new Buffer(['KEEPALIVE', '', 'keepAliveInterval', keepAliveInterval, '', '', ''].join('\r\n')) ));
  frame.writeFrame(c, 0, C.END_FRAME, 0, null);
}

// for oracle reverse connection
function serveOracle(c){
  var oSlotID, connSeq = ++gConnSeq, registered = false;
  debug('oracle seq(%d) connected', connSeq);

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
    oraSessions[oSlotID] = undefined;
  });

  c.on('error', function(err){
    console.error('oracle socket error', err, oSlotID);
    // todo: may release resource
  });

  return function processOracleFrame(head, cSlotID, type, flag, len, body){

    if (!registered) {
      registered = true;
      oSlotID = cSlotID;
      oraSessions[oSlotID] = new Session(oSlotID, body, c);
      signalOracleKeepAlive(c);
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
          signalOracleQuit(c);
        }
      }
    } else {
      // redirect frame to the right client socket untouched
      debug('from oracle: cSlotID=%d, cseq=%d, clients=%j', cSlotID, oraSessions[oSlotID].cSeq, Object.keys(clients));
      var client = clients[oraSessions[oSlotID].cSeq];
      // client may be killed this time
      if (client) {
        var cliSock = client.socket;
        cliSock.write(head);
        body && cliSock.write(body);
        client.cSlots[cSlotID] = undefined;
      }
      if (type === C.END_FRAME) {
        // reclaim oraSock for other use
        debug('oSlot is freed');
        if (oraSessions[oSlotID].quitting) {
          signalOracleQuit(oraSessions[oSlotID].socket);
        } else {
          afterNewAvailableOSlot(oSlotID, false);
        }
      }
    }
  };
}

exports.listenAll = function(port){
  exports.server4all.listen(port, function(){
    debug('listening to client/oracle at port:%d ', port);
  });
  return exports;
};

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

var keepAliveInterval;
exports.setKeepAlive = function(KAI){
  keepAliveInterval = KAI;
  setInterval(function(){
    freeOraSlotIDs.forEach(function(oSlotID){
      signalOracleKeepAlive(oraSessions[oSlotID].socket);
    });
  }, keepAliveInterval * 1000);
};

var monServices = {
  getStartConfig : function(cb){
    cb(startCfg);
  },
  getClientConfig : function(cb){
    cb(client_cfgs);
  },
  getOraSessions : function(cb){
    var oraSessions2 = new Array(oraSessionsHW);
    for (var i = 0; i < oraSessionsHW; i++) {
      if (oraSessions[i + 1]) {
        oraSessions2[i] = _.pick(oraSessions[i + 1], 'slotID', 'cSeq', 'cSlotID', 'quitting');
      }
    }
    cb(oraSessions2);
  },
  getClients : function(cb){
    var clients2 = [];
    for (n in clients) {
      var client = clients[n];
      if (client) {
        client2 = _.clone(client);
        delete client2.socket;
        client2.cSlots = client2.cSlots.slice(0, client2.cur_concurrency);
        clients2[n] = client2;
      }
    }
    cb(clients2);
  }
};

var startCfg;
exports.start = function(cfg){
  startCfg = cfg;
  client_cfgs = require(cfg.client_config);
  exports
    .listenAll(cfg.listen_port)
    .setKeepAlive(cfg.keep_alive_interval)
  ;
};

exports.start_by_env = function(){
  var env = process.env;
  exports.start({
    listen_port : env.listen_port || 1520,
    keep_alive_interval : env.keep_alive_interval || 280,
    client_config : env.client_config
  });
};