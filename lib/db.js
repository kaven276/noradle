var net = require('net')
  , cfg = require('./cfg.js')
  , logger = require('./logger.js')
  , port = process.argv[2] || cfg.oracle_port || '1521'
  , freeList = []
  , busyList = []
  , quitList = []
  , find = require('./util.js').find
  , waitQueue = []
  , sockSeq = 0
  ;

var waitTimeoutStats = {
  conn : 0,
  resp : 0,
  fin : 0,
  follow : 0,
  busyEnd : 0
};

function prnFreelist(env){
  return;
  var freeSeqs = freeList.map(function(item){
    return item.seq;
  });
  var busySeqs = busyList.map(function(item){
    return item.oraSock.seq;
  });
  logger.db('conn pool @%d: free: %j, busy: %j,', env, freeSeqs, busySeqs);
}

function handler4AskQuit(c2){
  var i, len, c;
  logger.db('oracle server(%d:%d) ask for quit', c2.sid, c2.serial);

  for (i = 0, len = busyList.length; i < len; i++) {
    c = busyList[i].oraSock;
    // if (!c) continue;
    if (c.sid === c2.sid && c.serial === c2.serial) {
      logger.db('oracle server(%d:%d) forbid to quit', c2.sid, c2.serial);
      c2.end('N');
      return;
    }
  }

  c2.end('Y');
  for (i = 0, len = freeList.length; i < len; i++) {
    c = freeList[i];
    if (c.sid === c2.sid && c.serial === c2.serial) {
      logger.db('oracle server(%d:%d) allow to quit', c2.sid, c2.serial);
      freeList.splice(i, 1);
      quitList.push(c);
      return;
    }
  }
  console.error('not busy not free connection is about to quit');
  process.exit(2);
}

var dbListener = net.createServer({allowHalfOpen : true}, function(c){
  c.once('data', function onHandshake(data){
    c.sid = data.readInt32BE(0);
    c.serial = data.readInt32BE(4);
    c.pseq = data.readInt32BE(8);
    c.seq = ++sockSeq;

    if (c.pseq < 0) {
      handler4AskQuit(c);
      return;
    }

    logger.db('oracle server(%d:%d) connected, now has %d', c.sid, c.serial, dbListener.connections);
    freeList.push(c);
    prnFreelist(1);
    execQueuedCB();
    c.on('end', function(pos){
      logger.db('oracle server(%d:%d) disconnected, now has %d', c.sid, c.serial, dbListener.connections);

      pos = find(quitList, c);
      if (~pos) {
        logger.db('oracle server(%d:%d) quit safely', c.sid, c.serial);
        quitList.splice(pos, 1);
        return;
      }

      // this is abnormal case
      pos = find(freeList, c);
      if (~pos) {
        console.warn('oraSock(%d:%d at pos %d in freeList is end.', c.sid, c.serial, pos);
        freeList.splice(pos, 1);
        return;
      }

      // this is abnormal case
      pos = find(busyList, c, function(p){
        return p.oraSock;
      });
      if (~pos) {
        var busyRec = busyList[pos];
        delete busyRec.oraSock;
        waitTimeoutStats.busyEnd++;
        console.warn('busy oraSock(%d:%d is end. %j', c.sid, c.serial, busyRec);
        busyList.splice(pos, 1);
        return;
      }

      console.warn('quit connection not in any of the three list');
    });
    prnFreelist(2);
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
  me.halfWayTime = null;
  me.response = false;
  me.following = false;
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
  prnFreelist(3);
}

function findFreeOraSockThen(env, cb){
  var oraSock = freeList.shift();
  if (oraSock) {
    logger.db('use free oraSock %d', oraSock.seq);
    var busyRec = new BusyRec(env, oraSock);
    busyList.push(busyRec);
    prnFreelist(4);
    cb(oraSock, busyRec);
  } else {
    waitQueue.push(new WaitRec(env, cb));
  }
}

function pushBackToFreelist(oraSock, busyRec){
  prnFreelist(7);
  logger.db('push back to %d', oraSock.seq);
  oraSock.removeAllListeners('data');
  oraSock.removeAllListeners('timeout');
  // mark this busyRec has no oraSock for use, css/fb depend on it to detect timeout clearup
  freeList.unshift(oraSock);
  var pos = find(busyList, busyRec);
  if (~pos) {
    busyList.splice(pos, 1);
  } else {
    logger.db('spot');
    console.warn('None busy oraSock is used in db.pushBackToFreelist !');
  }
  execQueuedCB();
  prnFreelist(5);
  // note: delete must after prnFreelist, or will report error
  delete busyRec.oraSock;
}

// the oraSock is completely unusable any more, end connection
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
  var now = Date.now()
    , tpl1 = 'Waiting too long(%dms) for the following(css/fb) for NO.%d oraSock(%d,%d)'
    , tpl2 = 'long busy call(no response) found for NO.%d oraSock(%d,%d) %s(ms)'
    ;
  //check for long running busy oraSocks, and emit LongRun event for killing, alerting, and etc ...
  busyList.forEach(function(busyRec){
    var oraSock = busyRec.oraSock;
    if (busyRec.following) {
      // the folloing css/fb will not check for timeout since they are already generated in oracle
      return;
    }
    if (busyRec.response) {
      if (busyRec.halfWayTime) {
        if (now - busyRec.halfWayTime > cfg.HalfWayTimeout) {
          waitTimeoutStats.follow++;
          logger.db(tpl1, now - busyRec.halfWayTime, oraSock.seq, oraSock.sid, oraSock.serial);
          delete busyRec.halfWayTime;
          pushBackToFreelist(oraSock, busyRec);
        }
      } else {
        // todo: find too long executions that has partial response returned, timeout it
        return;
      }
    } else {
      if (now - busyRec.date > cfg.ExecTimeout) {
        waitTimeoutStats.resp++;
        logger.db(tpl2, oraSock.seq, oraSock.sid, oraSock.serial, now - busyRec.date);
        oraSock.emit('timeout', now - busyRec.date);
        reportProtocolError(oraSock, busyRec);
        // todo: execute longer than 3s, may do alert, and kill the oracle session
      }
    }
  });
  // check if task wait too long, yes to call timeout callback and remove from wait queue
  waitQueue.forEach(function(item, i){
    if (now - item.date > cfg.FreeConnTimeout) {
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
exports.quitList = quitList;
exports.waitQueue = waitQueue;
exports.waitTimeoutStats = waitTimeoutStats;