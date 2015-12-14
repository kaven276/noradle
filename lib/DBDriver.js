/**
 * Created by cuccpkfs on 15-5-18.
 */

"use strict";

var frame = require('noradle-protocol').frame
  , debug = require('debug')('noradle:DBDriver')
  , Request = require('./Request.js').Request
  , C = require('noradle-protocol').constant
  , net = require('net')
  ;


/**
 *
 * @param stream: a TCP socket or UNIX socket or any stream, used to exchange message with NORADLE dispatcher
 * @constructor
 * DBPool.freeList is only for slotIDs
 */
function DBDriver(stream, auth){
  var me = this
    , release
    ;
  this.stream = stream;
  this.concurrency = 0;
  this.freeSlots = []; // it is local slots, not global
  this.waitQueue = [];
  this.requests = [];
  this.quitting = false;
  this.execCount = 0;

  // accept/parse response from dispatcher
  stream.on('connect', function(){
    debug('on connect to dispatcher');
    me.quitting = false;
    me._reset();
    release && release();
    // parse stream from dispatcher to frames, slotID is for local
    release = frame.wrapFrameStream(stream, C.CLIENT, C.DISPATCHER, function onFrame(head, cSlotID, type, flag, len, body){
      debug('frame cSlotID(%d) type(%d)', cSlotID, type);
      if (cSlotID) {
        if (type === C.ERROR_FRAME) {
          debug('error frame cSlotID(%d) type(%d), body=%s', cSlotID, type, body.toString());
        }
        me.requests[cSlotID].emit('frame', head, cSlotID, type, flag, len, body);
        if (type === C.END_FRAME && len === 0) {
          // end of response, recycle slotID
          debug('return slotID(%j)', cSlotID);
          delete me.requests[cSlotID];
          --me.execCount;
          if (cSlotID <= me.concurrency) {
            me.freeSlots.unshift(cSlotID);
            me.execQueuedCB();
          }
          if (me.quitting && me.execCount === 0) {
            stream.end();
          }
        }
        return;
      }
      // control message
      switch (type) {
        case C.SET_CONCURRENCY:
          var concurrency = JSON.parse(body.toString('ascii'))
            , freeSlots = me.freeSlots
            ;
          debug('got set_concurrency to %d, %j', concurrency, body);
          if (concurrency > me.concurrency) {
            // add freeSlots, pick request from queue
            for (var i = me.concurrency; i < concurrency; i++) {
              me.freeSlots.push(i + 1);
              me.execQueuedCB();
            }
          } else {
            // remove free slots whose id is higher than concurrency setting
            for (var i = freeSlots.length - 1; i >= 0; i--) {
              if (freeSlots[i] > concurrency) {
                freeSlots.splice(i, 1);
              }
            }
          }
          me.concurrency = concurrency;
          break;
        case C.WC_QUIT:
          debug('dispatcher tell me to quit');
          me.quitting = true;
          me._reset();
          if (me.execCount === 0) {
            stream.end();
          }
      }
    });
    // write first authenticate frame
    frame.writeFrame(stream, 0, C.AUTH_DATA, 0, new Buffer(JSON.stringify(auth)));
  });


}

DBDriver.prototype._cancelPendings = function(error){
  for (var cSlotID = 1, len = this.requests.length; cSlotID < len; cSlotID++) {
    var req = this.requests[cSlotID];
    if (req) {
      // may emulate a error frame
      debug('_cancelPendings cSlotID(%d)', cSlotID);
      this.stream.emit('frame', null, cSlotID, C.ERROR_FRAME, 0, (new buffer(error)).length, error);
      this.stream.emit('frame', null, cSlotID, C.END_FRAME, 0, 0, null);
    }
  }
};

/**
 * reset cSlots pathway resource to empty, so disallow new request
 * @private
 */
DBDriver.prototype._reset = function(){
  this.concurrency = 0;
  this.freeSlots = [];
};

/** got a request object to send request and receive response
 dbPool.findFree(env, dbSelector, function(err, request) {
   request.init(PROTOCOL, hprof);
   request.addHeaders( {name:value, ...}, prefix);
   request.addHeader(name, value);
   request.write(buffer);
   request.end(function(response){
     response.status;
     response.headers;
     response.on('frame', function(data){...});
     response.on('end', function(){...});
   });
 });
 */
DBDriver.prototype.findFree = function(env, dbSelector, cb, interrupter){
  var freeSlots = this.freeSlots
    , waitQueue = this.waitQueue
    ;
  if (freeSlots.length > 0) {
    var slotID = freeSlots.shift()
      , req = new Request(slotID, this.stream, env)
      ;

    debug('use slotID(%d) %j', slotID, freeSlots);
    this.requests[slotID] = req;
    ++this.execCount;
    cb(null, req);

    req.on('fin', function(){
      // slot.goFree();
    });

    req.on('error', function(){
      // slot.goFree();
    });
  } else {
    waitQueue.push(Array.prototype.slice.call(arguments, 0));
    debug('later push', waitQueue.length);
  }
  return interrupter;
};

DBDriver.prototype.execQueuedCB = function(){
  var waitQueue = this.waitQueue
    ;
  while (true) {
    var w = waitQueue.shift();
    if (!w) {
      return false;
    }
    if (w.aborted) {
      debug(w.env, 'abort in later queue');
      continue;
    }
    debug('executing a wait queue item', waitQueue.length);
    this.findFree.apply(this, w);
    return true;
  }
};

DBDriver.connect = function(addr, auth){
  var toDispatcherSocket = new net.Socket({allowHalfOpen : true})
    , dbDriver = new DBDriver(toDispatcherSocket, auth)
    , me = this
    ;

  function connect(){
    debug('try connect to dispatcher');
    toDispatcherSocket.removeAllListeners('readable');
    toDispatcherSocket.connect.apply(toDispatcherSocket, addr);
  }

  connect();
  toDispatcherSocket.on('end', function(){
    debug('socket end found!');
    dbDriver._reset();
    toDispatcherSocket.end();
  });
  toDispatcherSocket.on('error', function(err){
    dbDriver._reset();
    debug('socket error found!', err);
  });

  toDispatcherSocket.on('close', function(has_error){
    debug('socket closed', has_error);
    me.execCount > 0 && me._cancelPendings('dispatcher quit');
    setTimeout(connect, 1000);
  });
  return dbDriver;
};

exports.DBDriver = DBDriver;