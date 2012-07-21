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

function prnFreelist(){
  var seqs;
  logger.db();
  seqs = freeList.map(function(item){
    return item.seq;
  });
  logger.db('free socks : %j', seqs);
  seqs = busyList.map(function(item){
    return item.oraSock.seq;
  });
  logger.db('busy socks : %j', seqs);
}

var dbListener = net.createServer(function(c){
  logger.db('oracle server connected, now has ' + dbListener.connections);
  freeList.push(c);
  c.seq = ++sockSeq;
  prnFreelist();
  execQueuedCB();
  c.on('end', function(){
    logger.db('oracle server disconnected, now has ' + dbListener.connections);
    var pos = find(freeList, c);
    if (~pos) {
      console.log('oraSock at pos %d in freeList is end.', pos);
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

function BusyRec(oraSock){
  var me = this;
  me.oraSock = oraSock;
  me.date = Date.now();
  me.response = false;
  oraSock.once('data', function(){
    me.response = true;
  });
}

function WaitRec(cb){
  this.cb = cb;
  this.date = Date.now();
}

function execQueuedCB(){
  if (waitQueue.length === 0) return;
  var oraSock = freeList.shift();
  busyList.push(new BusyRec(oraSock));
  waitQueue.shift().cb(oraSock);
  logger.db('exec one waiting cb');
  prnFreelist();
}

function findFreeOraSockThen(cb){
  var oraSock = freeList.shift();
  if (oraSock) {
    logger.db('use free oraSock %d', oraSock.seq);
    busyList.push(new BusyRec(oraSock));
    prnFreelist();
    cb(oraSock);
  } else {
    waitQueue.push(new WaitRec(cb));
  }
}

function pushBackToFreelist(oraSock){
  logger.db('push back to %d', oraSock.seq);
  oraSock.removeAllListeners('data');
  oraSock.removeAllListeners('timeout');
  freeList.unshift(oraSock);
  execQueuedCB();
  var pos = find(busyList, oraSock, function(p){
    return p.oraSock;
  });
  if (~pos) {
    busyList.splice(pos, 1);
  }
  prnFreelist();
}

function reportProtocolError(oraSock){
  oraSock.removeAllListeners();
  oraSock.end();
  var pos = find(busyList, oraSock, function(p){
    return p.oraSock;
  });
  if (~pos) {
    busyList.splice(pos, 1);
  } else {
    console.warn('None busy oraSock is used in db.reportProtocolError !');
  }
}

/**
 * check for long running busy oraSocks, and emit LongRun event for killing, alerting, and etc ...
 */
setInterval(function(){
  var now = Date.now();
  busyList.forEach(function(item, idx){
    console.log('check long busy', idx, item.response, now, item.date, now - item.date);
    var oraSock = item.oraSock;
    if (item.response) {
      if (oraSock.halfWayTime) {
        if (now - oraSock.halfWayTime > 3000) {
          delete oraSock.halfWay;
          pushBackToFreelist(oraSock);
        }
      } else {
        return;
      }
    } else {
      if (now - item.date > 3000) {
        oraSock.emit('timeout', now - item.date);
        reportProtocolError(oraSock);
        // todo: execute longer than 3s, may do alert, and kill the oracle session
      }
    }
  });
}, 3000);

/**
 * check if task wait too long, yes to call timeout callback and remove from wait queue
 */
setInterval(function(){
  var now = Date.now();
  waitQueue.forEach(function(item, i){
    if (now - item.date > waitTimeout * 1000) {
      item.cb(); // null parameter stand for timeout
      waitQueue.splice(i, 1);
    }
  });
}, 3000);

exports.findFreeOraSockThen = findFreeOraSockThen;
exports.pushBackToFreelist = pushBackToFreelist;
exports.reportProtocolError = reportProtocolError;
