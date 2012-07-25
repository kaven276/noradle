var net = require('net')
  , cfg = require('./cfg.js')
  , logger = require('./logger.js')
  , port = process.argv[2] || cfg.oracle_port || '1521'
  , freeList = []
  , busyList = []
  , find = require('./util.js').find
  , waitQueue = []
  , waitTimeout = 30
  , sockSeq = 0
  ;

var waitTimeoutStats = {
  conn : 0,
  resp : 0,
  fin : 0,
  follow : 0
};

function prnFreelist(env){
  logger.db();
  var freeSeqs = freeList.map(function(item){
    return item.seq;
  });
  var busySeqs = busyList.map(function(item){
    return item.oraSock.seq;
  });
  logger.db('%d: free/busy socks : %j, %j,', env, freeSeqs, busySeqs);
}

var dbListener = net.createServer(function(c){
  logger.db('oracle server connected, now has ' + dbListener.connections);

  c.once('data', onHandshake);
  function onHandshake(data){
    c.sid = sid = data.readInt32BE(0);
    c.serial = serial = data.readInt32BE(4);
    if (data.length !== 8) {
      console.warn('first chunk for new oraSock is not 12 bytes length.');
      c.emit('data', data.slice(8));
    }
  }

  freeList.push(c);
  c.seq = ++sockSeq;
  prnFreelist();
  execQueuedCB();
  c.on('end', function(){
    logger.db('oracle server disconnected, now has ' + dbListener.connections);
    var pos = find(freeList, c);
    if (~pos) {
      logger.db('oraSock at pos %d in freeList is end.', pos);
      freeList.splice(pos, 1);
    } else {
      // todo: if busy oraSock closed, how to handle?
      console.error('busy oraSock is end');
    }
    prnFreelist();
  });
  c.on('error', function(){
    logger.db('oracle server connection has errors, now has ' + dbListener.connections);
  });
  c.setKeepAlive(true, 1000 * 60); // todo: if it's required?
});

dbListener.listen(port, function(){
  logger.db('PSP.WEB server is listening for oracle connection at port ' + port);
});

function BusyRec(env, oraSock){
  var me = this;
  me.env = env;
  me.oraSock = oraSock;
  me.date = Date.now();
  me.response = false;
  oraSock.once('data', function(){
    me.response = true;
  });
}

function WaitRec(env, cb){
  this.env = env;
  this.cb = cb;
  this.date = Date.now();
}

function execQueuedCB(){
  if (waitQueue.length === 0) return;
  var oraSock = freeList.shift()
    , waitRec = waitQueue.shift()
    , busyRec = new BusyRec(waitRec.env, oraSock)
    ;
  busyList.push(busyRec);
  waitRec.cb(oraSock, busyRec);
  logger.db('exec one waiting cb');
  prnFreelist();
}

function findFreeOraSockThen(env, cb){
  var oraSock = freeList.shift();
  if (oraSock) {
    logger.db('use free oraSock %d', oraSock.seq);
    prnFreelist();
    var busyRec = new BusyRec(env, oraSock);
    busyList.push(busyRec);
    cb(oraSock, busyRec);
  } else {
    waitQueue.push(new WaitRec(env, cb));
  }
}

function pushBackToFreelist(oraSock, busyRec){
  logger.db('push back to %d', oraSock.seq);
  oraSock.removeAllListeners('data');
  oraSock.removeAllListeners('timeout');
  freeList.unshift(oraSock);
  execQueuedCB();
  var pos = find(busyList, busyRec);
  if (~pos) {
    busyList.splice(pos, 1);
  } else {
    console.warn('None busy oraSock is used in db.pushBackToFreelist !');
  }
  prnFreelist();
}

function reportProtocolError(oraSock, busyRec){
  oraSock.removeAllListeners();
  oraSock.end();
  var pos = find(busyList, busyRec);
  if (~pos) {
    busyList.splice(pos, 1);
  } else {
    console.warn('None busy oraSock is used in db.reportProtocolError !');
  }
}

// database connection pool monitor
setInterval(function(){
  var now = Date.now();
  //check for long running busy oraSocks, and emit LongRun event for killing, alerting, and etc ...
  busyList.forEach(function(item){
    var oraSock = item.oraSock;
    if (item.response) {
      if (oraSock.halfWayTime) {
        if (now - oraSock.halfWayTime > cfg.HalfWayTimeout) {
          logger.db('Waiting too long(%dms) for the following(css/fb) for NO.%d oraSock(%d,%d)', now - oraSock.halfWayTime, oraSock.seq, oraSock.sid, oraSock.serial);
          delete oraSock.halfWay;
          pushBackToFreelist(oraSock);
          waitTimeoutStats.follow++;
        }
      } else {
        return;
      }
    } else {
      if (now - item.date > cfg.ExecTimeout) {
        logger.db('long busy call found for NO.%d oraSock(%d,%d) %s(ms)', oraSock.seq, oraSock.sid, oraSock.serial, now - item.date);
        oraSock.emit('timeout', now - item.date);
        reportProtocolError(oraSock);
        waitTimeoutStats.resp++;
        // todo: execute longer than 3s, may do alert, and kill the oracle session
      }
    }
  });
  // heck if task wait too long, yes to call timeout callback and remove from wait queue
  waitQueue.forEach(function(item, i){
    if (now - item.date > waitTimeout * 1000) {
      waitTimeoutStats.conn++;
      item.cb(); // null parameter stand for timeout
      waitQueue.splice(i, 1);
    }
  });
}, cfg.DBPoolCheckInterval);

exports.findFreeOraSockThen = findFreeOraSockThen;
exports.pushBackToFreelist = pushBackToFreelist;
exports.reportProtocolError = reportProtocolError;

// report to system monitor
exports.port = port;
exports.busyList = busyList;
exports.freeList = freeList;
exports.waitQueue = waitQueue;
