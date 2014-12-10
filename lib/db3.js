var net = require('net')
  , sys_cfg = require('./cfg.js')
  , logger = require('./logger.js')
  , C = require('./constant.js')
  , find = require('./util.js').find
  , logRegular = false
  , Request = require('./Request.js')
  , util = require('util')
  , cfgOverride = require('./util.js').override
  , events = require("events")
  ;

var EMPTY = 0
  , FREE = 1
  , BUSY = 2
  , FREEING = 3
  , CLOSED = 4
  , ERROR = 5
  , QUITTING = 6
  ;

/**
 * parse db names and session info from head of oraSock
 * @param data Buffer
 * @constructor
 */
function OraSockAttrSet(data){
  var dbNamesLen = data.readInt32BE(32)
    , dbNames = data.slice(36).toString().split('/')
    ;

  this.name = dbNames[0];
  this.domain = dbNames[1];
  this.uniqueName = dbNames[2];
  this.role = dbNames[3];

  this.oraSid = data.readInt32BE(4);
  this.oraSerial = data.readInt32BE(8);
  this.oraSpid = data.readInt32BE(12);
  this.slotID = data.readInt32BE(16);
  this.stime = Date.now();
  this.lifeMin = data.readInt32BE(20);
  this.reqCnt = data.readInt32BE(24);
  this.instance = data.readInt32BE(28);
}

/** called when a slot first created on first arrival of OSP connection */
function Slot(c, oraSockAttrSet, dbPool){
  // properties below has statistics
  this.hBytesRead = 0;
  this.hBytesWritten = 0;
  this.sockCount = 0;
  this.reqCount = 0;
  this.reqTimeAccum = 0; // ms
  this.bindSock(c, oraSockAttrSet);
  // properties below has value only when
  this.bTime = undefined;
  this.env = undefined;
  this.response = undefined;
  this.dbPool = dbPool;
  this.readQuit = Slot.prototype.readQuit.bind(this);
}
/** called when OSP connect to DBPool */
Slot.prototype.bindSock = function(oraSock, oraSockAttrSet){
  this.oraSock = oraSock;
  this.oraSockAttrSet = oraSockAttrSet;
  this.slotID = oraSockAttrSet.slotID;
  this.status = FREE;
  logRegular && this.log();
  logRegular && (logger.db((this.sockCount === 0) ? 'new slot and new oraSock' : 'reuse slot and new oraSock'));
  this.sockCount++;
};
/** if got data on FREE status, it must be quit signal from OSP */
Slot.prototype.readQuit = function(){
  var slot = this;
  if (slot.status === FREE) {
    slot.quit();
    slot.log();
    logger.db(' got quitting signal on free sts!');
    slot.oraSock.read();
  } else {
    slot.log();
    console.error(' got quitting signal on not free sts!', slot.status, slot.oraSock.read());
  }
};
/** mark slot busy */
Slot.prototype.goBusy = function(env){
  this.status = BUSY;
  this.reqCount++;
  this.env = env;
  this.bTime = Date.now();
  this.response = false;
  this.dbPool.busySet[this.slotID] = this;
  this.oraSock.removeListener('readable', this.readQuit);
  logRegular && this.log();
  logRegular && logger.db('req#%d socket go busy', this.reqCount);
};
/** mark slot free, return back to dbPool's freeList */
Slot.prototype.goFree = function(){
  var slot = this
    , slotID = this.slotID
    , dbPool = this.dbPool
    ;
  this.reqTimeAccum += (Date.now() - this.bTime);
  logRegular && slot.log();
  logRegular && logger.db('req#%d socket go free', slot.reqCount);
  delete dbPool.busySet[slotID];
  // WHEN from BUSY to QUITTING
  if (slot.status === QUITTING) {
    slot.log();
    logger.db(' got quitting signal tight after previous request!');
    return;
  }
  logRegular && this.log();
  logRegular && logger.db('req#%d socket go free', this.reqCount);
  slot.status = FREE;
  dbPool.freeList.unshift(slotID);
  if (!dbPool.execQueuedCB()) {
    slot.oraSock.on('readable', slot.readQuit);
  }
};
Slot.prototype.quit = function(freeList){
  var freeList = this.dbPool.freeList
    , pos = freeList.indexOf(this.slotID)
    ;
  if (pos >= 0) {
    freeList.splice(pos, 1);
  }
  this.status = QUITTING;
};
Slot.prototype.releaseSock = function(cause){
  var slotID = this.slotID
    , oraSock = this.oraSock
    , dbPool = this.dbPool
    ;
  if (!oraSock) {
    this.log();
    logger.db(' socket release from pool repeatly');
    return;
  }
  logRegular && this.log();
  logRegular && logger.db(' socket release from pool');

  this.hBytesRead += oraSock.bytesRead;
  this.hBytesWritten += oraSock.bytesWritten;
  oraSock.removeAllListeners();

  switch (this.status) {
    case FREE:
      logRegular && logger.db(' release from freeList');
      var freeList = dbPool.freeList;
      freeList.splice(find(freeList, slotID), 1);
      break;
    case FREEING:
      delete dbPool.busySet[slotID];
      break;
    case BUSY:
      delete dbPool.busySet[slotID];
      dbPool.waitTimeoutStats.busyEnd++;
      this.log();
      logger.db(' release from busyList', cause, this.status);
      oraSock.emit('socket_released', Date.now() - this.bTime);
      break;
    case QUITTING:
      this.log();
      logger.db(' release from quitting', cause, this.status);
      break;
    default:
      this.log();
      logger.db('quit connection not in ether free/freeing/busy state!', cause, this.status);
  }

  this.oraSock = undefined;
  this.status = CLOSED;
  oraSock.end();
};
Slot.prototype.log = function(){
  var o = this.oraSockAttrSet;
  logger.db('\npool slot (#%d - %d:%d) of %d @%s.%s', o.slotID, o.oraSid, o.oraSerial, 0, o.name, o.domain);
};

function DBPool(port, cfg){
  this.port = port || 1522;
  this.cfg = cfgOverride(sys_cfg, cfg || {});
  this.slots = [];
  this.freeList = [];
  this.busySet = {};
  this.waitQueue = [];
  this.listen();
  this.checkInterval();
  DBPool.pools[this.port] = this;
  this.waitTimeoutStats = {
    conn : 0,
    resp : 0,
    fin : 0,
    busyEnd : 0,
    cancel : 0
  };
}

DBPool.pools = {};

DBPool.prototype.listen = function(){
  var port = this.port
    , cfg = this.cfg
    ;
  var me = this
    , slots = me.slots
    , freeList = me.freeList
    ;
  var dbListener = net.createServer({allowHalfOpen : true}, function(c){
    var slot, slotID, oraSockAttrSet;

    (function(){
      var head, chunks = [];
      c.on('readable', onHandshake);

      function onHandshake(){
        var data = c.read();

        if (!chunks.length) {
          try {
            var ptoken = data.readInt32BE(0);
          } catch (e) {
            ptoken = -1;
          }
          if (ptoken !== 197610261) {
            console.warn('none oracle connection attempt found', data);
            c.end();
            c.destroy();
            return;
          }
        }

        chunks.push(data);
        if (data === null) {
          console.log('null data on hand-shake found');
          return;
        }
        if (data.length < 7) {
          console.log('partitial end marker on hand-shake found', chunks, data);
          return;
        }

        if (data.slice(-7).toString('ascii') !== '/080526') {
          logger.db('partial oracle connect data', data, data.slice(36), data.slice(36).toString());
          return;
        }
        head = Buffer.concat(chunks);
        c.removeListener('readable', onHandshake);

        oraSockAttrSet = new OraSockAttrSet(head);
        logger.db(oraSockAttrSet);
        slotID = oraSockAttrSet.slotID;
        init();
      }
    })();

    function init(){
      slot = slots[slotID];
      if (slot) {
        if (slot.oraSock) {
          // if broken connection is still holding and in use, release it for replacement of new connection
          logger.db(' slot replacement with new socket');
          slot.releaseSock('override');
          // slot.oraSock.destroy();
        }
        slot.bindSock(c, oraSockAttrSet);
      } else {
        slot = slots[slotID] = new Slot(c, oraSockAttrSet, me);
      }

      freeList.push(slotID);
      if (!me.execQueuedCB()) {
        slot.oraSock.on('readable', slot.readQuit);
      }

      c.on('end', function(){
        if (slot.oraSock !== c) {
          slot.log();
          logger.db(' socket fin received but slot.oraSock is not the same one');
          return;
        }
        logRegular && slot.log();
        logRegular && logger.db(' socket fin received');
        slot.releaseSock('on_end');
      });
      c.on('error', function(err){
        slot.log();
        logger.db(' socket error', err);
        slot.releaseSock('on_error');
      });
      if (cfg.oracle_keep_alive) {
        c.setKeepAlive(true, 1000 * cfg.oracle_keep_alive);
      } else {
        c.setKeepAlive(false);
      }
    }
  });

  dbListener.listen(port, function(){
    logger.db('NodeJS server is listening for oracle connection at port ' + port);
  });
};

function Interrupter(dbPool, env, dbSelector, cb){
  events.EventEmitter.call(this);
  this.dbPool = dbPool;
  this.env = env;
  this.cb = cb;
  this.aborted = false;
  this.overtime = false;
  this.sTime = Date.now();
}
util.inherits(Interrupter, events.EventEmitter);
Interrupter.prototype.abort = function(){
  logger.db(this.env, 'aborted, catched by db.js');
  this.aborted = true;
  var waitQueue = this.dbPool.waitQueue;
  var index = find(waitQueue, this);
  if (index >= 0) {
    logger.db(this.env, 'interrupted when waiting');
    waitQueue.splice(index, 1);
  }
};

/** got a request object to send request and receive response
 dbPool.findFree(env, dbSelector, function(err, request) {
   request.init(PROTOCOL, hprof);
   request.addHeaders(...);
   request.end(function(response){
     response.status;
     response.headers;
     response.on('data', function(data){...});
     response.on('end', function(){...});
   });
 });
 */
DBPool.prototype.findFree = function(env, dbSelector, cb, interrupter){
  var freeList = this.freeList
    , busySet = this.busySet
    , waitQueue = this.waitQueue
    ;
  if (interrupter) {
    // in the case of called from later queue
    if (interrupter.aborted) {
      cb(new Error('request aborted'));
      return;
    }
    if (interrupter.overtime) {
      cb(new Error('request wait db connection timeout'));
      return;
    }
  } else {
    interrupter = new Interrupter(this, env, dbSelector, cb);
  }
  if (freeList.length > 0) {
    var slotID = freeList.shift()
      , slot = this.slots[slotID]
      , oraSock = slot.oraSock
      , req = new Request(oraSock, env)
      ;
    slot.goBusy(env);
    cb(null, req);

    req.on('fin', function(){
      if (req.quitting) {
        slot.status = QUITTING;
      }
      slot.goFree();
    });

    req.on('error', function(){
      if (slotID in busySet) {
        delete busySet[slotID];
        slot.status = ERROR;
      } else {
        console.warn('None busy oraSock is used in db.reportProtocolError !');
      }
      slot.goFree();
    });
  } else {
    waitQueue.push(interrupter);
    logRegular && logger.db('later push', waitQueue.length);
  }
  return interrupter;
};

DBPool.prototype.execQueuedCB = function(){
  var waitQueue = this.waitQueue
    ;
  while (true) {
    var w = waitQueue.shift();
    if (!w) {
      return false;
    }
    if (w.aborted) {
      logger.db(w.env, 'abort in later queue');
      ;
      continue;
    }
    logger.db('executing a wait queue item', waitQueue.length);
    this.findFree(w.env, w.dbSelector, w.cb, w);
    return true;
  }
}

// database connection pool monitor
DBPool.prototype.checkInterval = function(){
  var dbPool = this
    , cfg = dbPool.cfg
    ;
  setInterval(function(){
    var slots = this.slots
      , busySet = this.busySet
      , waitQueue = this.waitQueue
      ;
    var now = Date.now()
      ;
    //check for long running busy oraSocks, and emit LongRun event for killing, alerting, and etc ...
    for (var slotID in busySet) {
      var slot = slots[slotID]
        , oraSock = slot.oraSock
        ;
      if (!oraSock) return;
      if (slot.response) {
        // todo: find too long executions that has partial response returned, timeout it
      } else {
        if (now - slot.bTime > cfg.ExecTimeout) {
          waitTimeoutStats.resp++;
          slot.log();
          logger.db('response_timeout by interval checker', now - slot.bTime);
          // todo: execute longer than 3s, may do alert, and kill the oracle session
        }
      }
    }
    // check if task wait too long, yes to call timeout callback and remove from wait queue
    // low index item is waiting longer
    for (var i = waitQueue.length - 1; i >= 0; i--) {
      var w = waitQueue[i]
        ;
      if (now - w.sTime > cfg.FreeConnTimeout) {
        waitTimeoutStats.conn++;
        w.overtime = true;
        // later.splice(i, 1);
        logger.db('wait free oraSock timeout by interval checker', now - w.sTime);
      }
    }
  }, cfg.DBPoolCheckInterval);
};

exports.DBPool = DBPool;
exports.waitTimeoutStats = waitTimeoutStats;

/*
 * todo:
 */