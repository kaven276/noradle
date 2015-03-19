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
  ;

// for accept front end request
// may accept from different front nodejs connection request
var server = net.createServer({allowHalfOpen : true}, function(c){
  var seq = ++gseq;
  debug('node(%d) connected', seq);

  var freeSlotID = freeList.shift()
    , marker = new Buffer(4)
    ;
  if (!freeSlotID) {
    // no available free slot, disconnect client
    marker.writeInt32BE(197610262, 0);
    c.end(marker);
    c.destroy();
    debug('node(%d) connected but no free', seq);
    return;
  }

  var slot = oraPool[freeSlotID]
    ;
  c.write(slot.head);
  c.pipe(slot.oraSock, {end : false}).pipe(c);
  debug('node(%d) use free slot %s, %j', seq, freeSlotID, freeList);

  c.on('end', function(){
    debug('node(%d) disconnected', seq);
    // c.end();
    if (oraPool[freeSlotID]) {
      freeList.unshift(freeSlotID);
      debug('node(%d) return back slot %s, %j', seq, freeSlotID, freeList);
    }
  });
});


var oraPool = new Array(1000)
  , freeList = []
  , connSeq = 0
  ;
// for oracle reverse connection
// check magic number only
var pool = net.createServer(function(c){
  debug('oracle connected');
  connSeq++;
  var slotID;
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
    debug('add new slot(%s), freeList=%j', slotID, freeList);
  };

  c.on('end', function(){
    debug('oracle disconnected');
    // find free list and remove from free list
    delete oraPool[slotID];
    var pos = freeList.indexOf(slotID);
    if (pos >= 0) {
      freeList.splice(pos, 1);
      debug('removed slot(%s), freeList=%j', slotID, freeList);
    } else {
      debug('not found on end slotID(%s) in freeList(%j)', slotID, freeList);
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


