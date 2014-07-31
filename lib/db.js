var net = require('net')
  , cfg = require('./cfg.js')
  , logger = require('./logger.js')
  , C = require('./constant.js')
  , REQ_END_MARK = C.REQ_END_MARK
  , port = process.argv[2] || cfg.oracle_port || '1521'
  , dbPool = []
  , freeList = []
  , busySet = {}
  , find = require('./util.js').find
  , waitQueue = []
  , logRegular = false
  ;

var EMPTY = 0
  , FREE = 1
  , BUSY = 2
  , FREEING = 3
  , CLOSED = 4
  , ERROR = 5
  ;

var waitTimeoutStats = {
  conn : 0,
  resp : 0,
  fin : 0,
  busyEnd : 0,
  cancel : 0
};

/**
 * parse db names from head of oraSock
 * @param data Buffer
 * @constructor
 */
function DB(data){
  var dbNamesLen = data.readInt32BE(20)
    , dbNames = data.slice(24).toString().split('/')
    ;
  this.instance = data.readInt32BE(16);
  this.name = dbNames[0];
  this.domain = dbNames[1];
  this.uniqueName = dbNames[2];
  this.role = dbNames[3];
}

function Slot(c, slotID, oraSid, oraSerial, db){
  // properties below has statistics
  this.hBytesRead = 0;
  this.hBytesWritten = 0;
  this.sockCount = 0;
  this.reqCount = 0;
  this.reqTimeAccum = 0; // ms
  this.bindSock(c, slotID, oraSid, oraSerial, db);
  // properties below has value only when
  this.bTime = undefined;
  this.env = undefined;
  this.response = undefined;
}
Slot.prototype.bindSock = function(oraSock, slotID, oraSid, oraSerial, db){
  this.oraSock = oraSock;
  this.slotID = slotID;
  this.oraSid = oraSid;
  this.oraSerial = oraSerial;
  this.db = db;
  this.status = FREE;
  logRegular && this.log();
  if (this.sockCount === 0) {
    logRegular && logger.db('new slot and new oraSock');
  } else {
    logRegular && logger.db('reuse slot and new oraSock');
  }
  this.sockCount++;
};
Slot.prototype.goBusy = function(env){
  this.status = BUSY;
  this.reqCount++;
  this.env = env;
  this.bTime = Date.now();
  this.response = false;
  busySet[this.slotID] = this;
  var me = this;
  this.oraSock.once('data', function(){
    me.response = true;
  });
  logRegular && this.log();
  logRegular && logger.db('req#%d socket go busy', this.reqCount);
};
Slot.prototype.goFree = function(){
  var me = this
    , slotID = this.slotID
    ;
  this.status = FREEING;
  this.reqTimeAccum += (Date.now() - this.bTime);
  var oraSock = this.oraSock;
  oraSock.removeAllListeners('data'); // for psp.web.js and timeout monitor
  oraSock.removeAllListeners('response_timeout');
  oraSock.removeAllListeners('socket_released');
  logRegular && this.log();
  logRegular && logger.db('freeing');
  oraSock.once('data', function(data){
    if (data.toString() !== REQ_END_MARK) {
      logRegular && me.log();
      logRegular && logger.db('OGW/Servlet not read request completely!');
      return;
    }
    me.status = FREE;
    delete busySet[slotID];
    freeList.unshift(slotID);
    execQueuedCB();
    logRegular && me.log();
    logRegular && logger.db('req#%d socket go free', me.reqCount);
  });
  oraSock.write(REQ_END_MARK);
};
Slot.prototype.releaseSock = function(cause){
  var slotID = this.slotID
    , oraSock = this.oraSock
    , pos
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
      freeList.splice(find(freeList, slotID), 1);
      break;
    case FREEING:
      delete busySet[slotID];
      break;
    case BUSY:
      delete busySet[slotID];
      waitTimeoutStats.busyEnd++;
      this.log();
      logger.db(' release from busyList', cause, this.status);
      oraSock.emit('socket_released', Date.now() - this.bTime);
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
  logger.db('\npool slot (#%d - %d:%d) of %d @%s %s', this.slotID, this.oraSid, this.oraSerial, 0);
};

var dbListener = net.createServer({allowHalfOpen : true}, function(c){

  var slot, slotID, oraSid, oraSerial, db;
  c.once('data', onHandshake);

  function onHandshake(data){
    try {
      var ptoken = data.readInt32BE(0);
    } catch (e) {
      ptoken = -1;
    }
    if (ptoken !== 197610261) {
      console.warn('none oracle connection attempt found');
      c.end();
      c.destroy();
      return;
    }
    oraSid = data.readInt32BE(4);
    oraSerial = data.readInt32BE(8);
    slotID = data.readInt32BE(12);
    db = new DB(data);
    // console.log('-', data.length, dbNames);
    init();
  }

  function init(){
    slot = dbPool[slotID];
    if (slot) {
      if (slot.oraSock) {
        // if broken connection is still holding and in use, release it for replacement of new connection
        logger.db(' slot replacement with new socket');
        slot.releaseSock('override');
        // slot.oraSock.destroy();
      }
      slot.bindSock(c, slotID, oraSid, oraSerial, db);
    } else {
      slot = dbPool[slotID] = new Slot(c, slotID, oraSid, oraSerial, db);
    }

    freeList.push(slotID);
    execQueuedCB();

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
    c.on('timeout', function(){
      // see if is using
      logRegular && slot.log();
      logRegular && logger.db(' socket idle timeout');
      slot.releaseSock('on_idle_timeout'); // todo: if socket is in use, it may cause bug
      c.end();
    });
    c.setTimeout(1000 * cfg.oracle_timeout);
    c.setKeepAlive(true, 1000 * cfg.oracle_keep_alive); // todo: if it's required?
  }
});

dbListener.listen(port, function(){
  logger.db('NodeJS server is listening for oracle connection at port ' + port);
});

function findFreeOraSockThen(env, cliSock, cb){
  if (freeList.length > 0) {
    var slotID = freeList.shift()
      , slot = dbPool[slotID]
      , oraSock = slot.oraSock
      ;
    slot.goBusy(env);
    cb(null, oraSock, slotID, function(err){
      pushBackToFreelist(err, oraSock, slotID);
    });
  } else {
    waitQueue.push(new WaitRec(env, cliSock, cb));
  }
}

function pushBackToFreelist(err, oraSock, slotID){
  // logSts();
  if (err) {
    // the oraSock is completely unusable any more, end connection
    oraSock.removeAllListeners();
    oraSock.end();
    if (slotID in busySet) {
      delete busySet[slotID];
      dbPool[slotID].status = ERROR;
    } else {
      console.warn('None busy oraSock is used in db.reportProtocolError !');
    }
  } else {
    // mark this busyRec has no oraSock for use, css/fb depend on it to detect timeout clearup
    dbPool[slotID].goFree();
  }
}

function WaitRec(env, cliSock, cb){
  this.env = env;
  this.cliSock = cliSock;
  this.cb = cb;
  this.date = Date.now();
}

function execQueuedCB(){
  var waitRec, hit, cliSock;
  do {
    if (waitQueue.length === 0) return;
    waitRec = waitQueue.shift();
    cliSock = waitRec.cliSock;
    hit = (cliSock === null) || (cliSock && cliSock.writable);
    hit || waitTimeoutStats.cancel++;
  } while (!hit);
  var slotID = freeList.shift()
    , slot = dbPool[slotID]
    , oraSock = slot.oraSock
    ;
  slot.goBusy(waitRec.env);
  logRegular && slot.log();
  logRegular && logger.db('processing one waiting client request');
  waitRec.cb(null, oraSock, slotID, function(err){
    pushBackToFreelist(err, oraSock, slotID);
  });
}

// database connection pool monitor
setInterval(function(){
  var now = Date.now()
    ;
  //check for long running busy oraSocks, and emit LongRun event for killing, alerting, and etc ...
  for (var slotID in busySet) {
    var slot = dbPool[slotID]
      , oraSock = slot.oraSock
      ;
    if (slot.response) {
      // todo: find too long executions that has partial response returned, timeout it
    } else {
      if (now - slot.bTime > cfg.ExecTimeout) {
        waitTimeoutStats.resp++;
        slot.log();
        logger.db('response_timeout by interval checker', now - slot.bTime);
        oraSock.emit('response_timeout', now - slot.bTime);
        pushBackToFreelist(new Error('response_timeout'), oraSock, slotID);
        // todo: execute longer than 3s, may do alert, and kill the oracle session
      }
    }
  }
  // check if task wait too long, yes to call timeout callback and remove from wait queue
  // low index item is waiting longer
  for (var i = waitQueue.length - 1; i >= 0; i--) {
    var item = waitQueue[i];
    if (now - item.date > cfg.FreeConnTimeout) {
      waitTimeoutStats.conn++;
      item.cb(new Error('timeout'));
      waitQueue.splice(i, 1);
    }
  }
}, cfg.DBPoolCheckInterval);

exports.findFreeOraSockThen = findFreeOraSockThen;

// report to system monitor
exports.port = port;
exports.dbPool = dbPool;
exports.freeList = freeList;
exports.busySet = busySet;
exports.waitQueue = waitQueue;
exports.waitTimeoutStats = waitTimeoutStats;
exports.server = dbListener;