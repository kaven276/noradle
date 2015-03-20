/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 13-5-16
 * Time: 下午2:47
 */
console.log(process.execPath);

var net = require('net')
  , C = require('./constant.js')
  , debug = require('debug')('noradle:inhub')
  , gseq = 0
  , marker = (new Buffer(4)).writeInt32BE(197610262, 0)
  ;

// for accept front end request
// may accept from different front nodejs connection request
exports.server4node = net.createServer({allowHalfOpen : true}, function(c){
  var seq = ++gseq;
  debug('node(%d) connected', seq);

  var slotID = freeList.shift()
    ;
  if (!slotID) {
    // no available free slot, disconnect client
    c.end(marker);
    c.destroy();
    debug('node(%d) connected but no free', seq);
    return;
  }

  var slot = oraPool[slotID]
    ;
  slot.oraSock.removeAllListeners('readable');
  c.write(slot.head);
  c.pipe(slot.oraSock, {end : false}).pipe(c, {end : true});
  debug('node(%d) use free slot %s, %j', seq, slotID, freeList);

  c.on('end', function(){
    debug('node(%d) disconnected', seq);
    slot.oraSock.unpipe(c);
    // c.end();
    if (!oraPool[slotID]) {
      // not in oraPool, so oracle is disconnected, and not connected again yet
      debug('node(%d) oraPool(%d) no data, %j', seq, slotID, freeList);
    } else if (~freeList.indexOf(slotID)) {
      // in freeList, it must be another new slot with same slotID
      debug('node(%d) oraPool(%d) in freelist, %j', seq, slotID, freeList);
    } else {
      freeList.unshift(slotID);
      debug('node(%d) return back slot %s, %j', seq, slotID, freeList);
    }
  });

  c.on('error', function(err){
    console.error(err, slotID);
  })
});


var oraPool = new Array(1000)
  , freeList = []
  , gConnSeq = 0
  ;
// for oracle reverse connection
// check magic number only
exports.server4oracle = net.createServer(function(c){
  var slotID, connSeq = ++gConnSeq;
  debug('oracle(%d) connected', connSeq);

  c.on('readable', onHandshake);

  var head, chunks = [], chunkSeq = 0;

  function onHandshake(){
    var data = c.read();
    chunkSeq++;

    if (data === null) {
      debug('onHandshake(%d,%d): data === null', connSeq, chunkSeq);
      return;
    } else {
      chunks.push(data);
    }

    if (chunks.length === 1) {
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

    if (data.length < 7) {
      debug('onHandshake(%d,%d): data.length < 7', connSeq, chunkSeq);
      debug(chunks, data);
      return;
    }
    if (data.slice(-7).toString('ascii') !== '/080526') {
      debug('onHandshake(%d,%d): data.slice(-7).toString("ascii"") !== "/080526"', connSeq, chunkSeq);
      debug('partial oracle connect data', data, data.slice(36), data.slice(36).toString());
      return;
    }

    head = Buffer.concat(chunks);
    c.removeListener('readable', onHandshake);

    slotID = head.readInt32BE(16);
    oraPool[slotID] = {oraSock : c, head : head};
    freeList.push(slotID);
    debug('oracle(%s,%s) slot add, freeList=%j', connSeq, slotID, freeList);

    c.on('readable', readQuit);
  }

  function readQuit(){
    // oraSock must be in freeList
    debug('oracle(%d,%d) got quit signal', slotID, connSeq);
    c.read(4);
  }

  c.on('end', function(){
    debug('oracle(%d,%d) disconnected', slotID, connSeq);
    // find free list and remove from free list
    delete oraPool[slotID];
    var pos = freeList.indexOf(slotID);
    if (pos >= 0) {
      freeList.splice(pos, 1);
      debug('oracle(%d,%d) slot removed, freeList=%j', connSeq, slotID, freeList);
    } else {
      debug('oracle(%d,%d) slot not in freeList.freeList(%j)', connSeq, slotID, freeList);
      // 应该将对应的 node socket 发送 tcp fin
      // 而且可能马上就会有新的 oracle 连接建立，取代原先的连接
      //
    }
  });
});

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

