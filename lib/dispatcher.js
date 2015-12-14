#!/usr/bin/env node

/**
 * Created by kaven276@vip.sina.com on 15-5-18.
 * dispatcher is a frame switcher who provide dynamic virtual connection for client request and oracle response
 * design principle: simple, robust, stable long running
 *
 * usage:
 * require('noradle').dispatcher.start({
 *   listen_port: the port to listen for oracle reversed connections, client connections, and monitor connections,
 *   keep_alive_interval: number of seconds to send keep_alive frame to oracle,
 *   client_config: the path client configuration file is located on
 *   db: {
 *     ... as session db to check oracle connection is from right db
 * }
 *
 * or use command line
 * dispatcher --listen_port=xxx keep_alive_interval=xxx client_config=xxx
 *
 * functions:
 * 1. check and hold oracle reversed connections, keep-alive to oracle
 * 2. authenticate and hold client connections
 * 3. establish/destroy virtual connections from client to oracle process
 * 4. assign concurrency to clients statically and dynamically
 * 5. collect/provide current/accumulative statistics
 *
 * variable explain:
 * oSlotID : global oracle slot id
 * cSlotID : local to one client connection
 * freeOraSlotIDs : all free oracle slot IDs, more recently used at head, new added at tail
 * clients[cseq].cSlots[cSlotID] = { oSlotID: number, buf: frames }
 * oraSessions[oSlotID] = {cSeq: number, cSlotID: number, cSock: socket}
 * queue[n] = [cSeq, cSlotID]
 */
"use strict";

function Stats(){
  this.reqCount = 0;
  this.respCount = 0;
  this.waitTime = 0;
  this.respDelay = 0;
  this.execTime = 0;
  this.inBytes = 0;
  this.outBytes = 0;
}

var net = require('net')
  , fs = require('fs')
  , dnode = require('dnode')
  , frame = require('noradle-prococol').frame
  , _ = require('underscore')
  , debug = require('debug')('noradle:dispatcher')
  , C = require('noradle-protocol').constant
  , queue = []
  , client_cfgs
  , clients = new Array(C.MAX_CLIENTS)
  , clientsHW = 0
  , oraSessions = new Array(C.ORA_MAX_SLOTS)
  , oraSessionsHW = 0
  , freeOraSlotIDs = []
  , gConnSeq = 0
  , monitors = []
  , oSlotCnt = 0
  , concurrencyHW = 0
  ;

function Client(c, cSeq, cid){
  this.cTime = Date.now();
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

function bindOSlot(req, cSeq, cSlotID, cTime, oSlotID){
  req.oSlotID = oSlotID;
  var oraSlot = oraSessions[oSlotID];
  oraSlot.cSeq = cSeq;
  oraSlot.cSlotID = cSlotID;
  oraSlot.cTime = cTime;
}

function unBindOSlot(oSlot){
  delete oSlot.cSeq;
  delete oSlot.cSlotID;
  delete oSlot.cTime;
}

exports.server4all = net.createServer({allowHalfOpen : true}, function(c){

  frame.wrapFrameStream(c, C.DISPATCHER, mmChecker);

  function mmChecker(mm){
    switch (mm) {
      case C.CLIENT:
        c.on('frame', serveClient(c));
        return true;
      case C.ORACLE:
        c.on('frame', serveOracle(c));
        return true;
      case C.MONITOR:
        c.removeAllListeners('readable');
        serveMonitor(c);
        return true;
      default:
        return false;
    }
  }
});

function findMinFreeCSeq(){
  for (var i = 1; i < clientsHW; i++) {
    if (!clients[i]) return i;
  }
  return clientsHW++;
}

// may accept from different front nodejs connection request
function serveClient(c){
  var cSeq, client, cStats, authenticated = false;

  debug('node(new) connected');

  c.on('end', function(){
    c.end();
    debug('node(%d) disconnected', cSeq);
  });

  c.on('error', function(err){
    console.error('client socket error', err, cSeq);
    delete clients[cSeq];
  });

  c.on('close', function(has_error){
    debug('client(%d) close', cSeq);
    delete clients[cSeq];
  });


  return function processClientFrame(head, cSlotID, type, flag, len, body){
    var cid;
    if (!authenticated) {
      if (!(cid = authenticate(body))) {
        //todo: may tell what's wrong to client
        c.end();
        return;
      }

      authenticated = true;
      cSeq = findMinFreeCSeq();
      client = clients[cSeq] = new Client(c, cSeq, cid);
      cStats = client.cfg.stats;
      debug('node(%d) connected', cSeq);
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

    cStats.inBytes += (8 + len);
    if (type === C.HEAD_FRAME) {
      var cidBuf = new Buffer(client.cid + '\r\n' + cSlotID + '\r\n');
      cStats.reqCount++;
      req = client.cSlots[cSlotID] = {rcvTime : Date.now()};
      // for the first frame of a request
      if (freeOraSlotIDs.length > 0) {
        oSlotID = freeOraSlotIDs.shift();
        bindOSlot(req, cSeq, cSlotID, client.cTime, oSlotID);
        oSock = oraSessions[oSlotID].socket;
        oSock.write(head);
        oSock.write(body);
        oSock.write(cidBuf);
        req.sendTime = Date.now();
        debug('head frame use slot(%d)', oSlotID);
      } else {
        // init buf, add to queue
        req.buf = [head, body, cidBuf];
        queue.push([cSeq, cSlotID]);
        debug('head frame no free slot');
      }

    } else {
      req = client.cSlots[cSlotID];
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
        debug('successive frame add to buf, wait oslot, chunks=%d', req.buf.length);
      }
    }

  }
}

function Session(oSlotID, body, socket){

  oSlotCnt++;

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
    inst : body.readInt32BE(0),
    cfg_id : dbNames[4]
  };

  for (var n in db) {
    if (startCfg.db[n] && startCfg.db[n] !== db[n]) {
      // todo: add warning
      debug('db[%s] not match %s(config) != %s(incoming)', n, startCfg.db[n], db[n]);
      debug(db);
      debug(startCfg.db);
      return false;
    }
  }

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
  debug('queue length=%d', queue.length);
  var w = queue.shift();
  if (w) {
    // tell pmon queue length
    if (queue.length + oSlotCnt > concurrencyHW) {
      signalAskOSP(oraSessions[oSlotID].socket, queue);
    }
    // use slotID to send w request
    var cSeq = w[0]
      , cSlotID = w[1]
      , client = clients[cSeq]
      , req = client.cSlots[cSlotID]
      , buf = req.buf
      ;
    debug('unshift queue item cseq=%d, cSlotID=%d, req(chunks)=%d', cSeq, cSlotID, req.buf.length);
    oraSessions[oSlotID].socket.write(Buffer.concat(buf));
    delete req.buf;
    bindOSlot(req, cSeq, cSlotID, client.cTime, oSlotID);
    req.sendTime = Date.now();
    debug('switch %j to use oSlot(%d)', w, oSlotID);
  } else {
    concurrencyHW = oSlotCnt;
    if (isNew) {
      freeOraSlotIDs.push(oSlotID);
    } else {
      freeOraSlotIDs.unshift(oSlotID);
    }
  }
}

function signalAskOSP(c, queue){
  concurrencyHW = queue.length + oSlotCnt;
  var arr = ['ASK_OSP', '', 'queue_len', queue.length, 'oslot_cnt', oSlotCnt];
  frame.writeFrame(c, 0, C.HEAD_FRAME, 0, (new Buffer(arr.join('\r\n')) + '\r\n\r\n\r\n'));
  frame.writeFrame(c, 0, C.END_FRAME, 0, null);
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
    c.end();
    debug('oracle seq(%s) oSlot(%s) disconnected', connSeq, oSlotID);
    // find free list and remove from free list
    var pos = freeOraSlotIDs.indexOf(oSlotID);
    if (pos >= 0) {
      // if in free list, just remove from free list
      freeOraSlotIDs.splice(pos, 1);
      debug('oracle seq(%s) oSlot(%s) slot removed, freeListCount=%d', connSeq, oSlotID, freeOraSlotIDs.length);
    } else {
      // if in busy serving a client request, raise a error for the req
      var oSlot = oraSessions[oSlotID]
        , cSlotID = oSlot.cSlotID
        , client = clients[oSlot.cSeq || 0]
        ;
      if (client && oSlot.cTime === client.cTime) {
        debug('busy oSlot(%s) slot socket end, cSeq(%s,%d), cSlotid(%d)', oSlotID, client.cid, oSlot.cSeq, cSlotID);
        frame.writeFrame(client.socket, cSlotID, C.ERROR_FRAME, 0, 'oracle connection break!');
        frame.writeFrame(client.socket, cSlotID, C.END_FRAME, 0);
        delete client.cSlots[cSlotID];
      }
    }
    delete oraSessions[oSlotID];
    oSlotCnt--;
  });

  c.on('error', function(err){
    console.error('oracle socket error', err, oSlotID);
    delete oraSessions[oSlotID];
    oSlotCnt--;
    // todo: may release resource
  });

  return function processOracleFrame(head, cSlotID, type, flag, len, body){

    if (!registered) {
      registered = true;
      oSlotID = cSlotID;
      var oraSession = new Session(oSlotID, body, c);
      if (!oraSession) {
        setTimeout(function(){
          signalOracleQuit(c);
        }, keepAliveInterval * 1000);
        return;
      }
      oraSessions[oSlotID] = oraSession;
      signalOracleKeepAlive(c);
      debug('oracle seq(%s) oSlot(%s) slot add, freeListCount=%d', connSeq, oSlotID, freeOraSlotIDs.length);
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
      debug('from oracle: cSlotID=%d, cseq=%d, type=%d', cSlotID, oraSessions[oSlotID].cSeq, type);
      var oraSession = oraSessions[oSlotID]
        , client = clients[oraSession.cSeq]
        ;
      // client may be killed this time or a client with same cSeq connected
      if (client && oraSession.cTime === client.cTime) {
        var cliSock = client.socket;
        cliSock.write(head);
        body && cliSock.write(body);

        var cStats = client.cfg.stats
          , req = client.cSlots[cSlotID]
          ;
        cStats.outBytes += (8 + len);
        if (type === C.HEAD_FRAME) {
          cStats.respDelay += (Date.now() - req.sendTime);
        }
        if (type === C.END_FRAME) {
          cStats.respCount++;
          cStats.waitTime += (req.sendTime - req.rcvTime);
          cStats.execTime += (Date.now() - req.sendTime);
          delete client.cSlots[cSlotID];
        }
      } else {
        // requesting client is gone
      }
      if (type === C.END_FRAME) {
        // reclaim oraSock for other use
        debug('oSlot is freed');
        unBindOSlot(oraSession);
        if (oraSession.quitting) {
          signalOracleQuit(c);
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
    var clients2 = {};
    for (var i = 0; i < clientsHW; i++) {
      var client = clients[i];
      if (client) {
        var client2 = _.clone(client);
        delete client2.socket;
        var cSlots = client2.cSlots = {};
        _.each(client.cSlots.slice(0, client.cur_concurrency + 1), function(cSlot, cSlotID){
          if (!cSlot) return;
          cSlots[cSlotID] = _.omit(cSlot, 'buf');
        });
        clients2[i] = client2;
      }
    }
    cb(clients2);
  }
};

function serveMonitor(c){
  c.pipe(dnode(monServices)).pipe(c);
  monitors.push(c);
  c.on('end', function(){
    c.end();
  });
  c.on('close', function(){
    monitors.splice(monitors.indexOf(c), 1);
  });
}


var startCfg;
exports.start = function(cfg){
  startCfg = cfg;
  if (cfg.client_config) {
    client_cfgs = require(cfg.client_config);
  } else {
    client_cfgs = {
      demo : {
        min_concurrency : 3,
        max_concurrency : 3,
        passwd : 'demo'
      }
    };
  }
  _.each(client_cfgs, function(v, n){
    v.stats = new Stats();
  });
  exports
    .listenAll(cfg.listen_port)
    .setKeepAlive(cfg.keep_alive_interval)
  ;
};

exports.start_by_env = function(){
  var env = process.env
    , args = process.argv
    ;
  exports.start({
    listen_port : args[2] || env.listen_port || 1522,
    client_config : args[3] || env.client_config,
    keep_alive_interval : env.keep_alive_interval || 280,
    db : {
      name : env.db_name,
      domain : env.db_domain,
      unique : env.db_unique_name,
      inst : parseInt(env.instance),
      role : env.db_role,
      cfg_id : env.db_cfg_id
    }
  });
};

// graceful quit support
// stop listen and wait all pending request to finish
// after 1 minute, force quit any way
process.on('SIGTERM', function gracefulQuit(){
  debug('SIGTERM received, new connection/request is not allowed, when all request is done, process will quit safely');

  // no more client/oracle/monitor can connect to me
  exports.server4all.close(function(){
    debug('all client/oracle/monitor connections is closed, safe to quit');
    process.exit(0);
  });

  // send quit signal to every client to close connection
  for (var i = 0; i < clientsHW; i++) {
    var client = clients[i];
    client && frame.writeFrame(client.socket, 0, C.WC_QUIT, 0);
  }

  // send quit signal to every free oracle connection
  for (var i = 1; i <= oraSessionsHW; i++) {
    var oSlot = oraSessions[i];
    if (oSlot) {
      oSlot.quitting = true;
      var index = freeOraSlotIDs.indexOf(i);
      if (index >= 0) {
        freeOraSlotIDs.splice(index, 1);
        signalOracleQuit(oraSessions[i].socket);
      }
    }
  }

  // todo: close all monitor connections directly
  monitors.forEach(function(c){
    c.end();
  });

  setInterval(function(){
    exports.server4all.getConnections(function(err, count){
      debug('remain %d connections on server', count);
    });
  }, 1000);

  // anyway, force quit after 1 minute
  setTimeout(function(){
    process.exit(1);
  }, 15 * 1000);
});

process.on('SIGUSER2', function reloadConfig(){
  // reload configuration
});

if (process.argv[1].match(/.*\/noradle-dispatcher$/) || process.argv[1] === __filename) {
  exports.start_by_env();
}