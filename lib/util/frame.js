/**
 * Created by cuccpkfs on 15-5-13.
 * wrap a readable/writable stream lik TCP/UNIX socket to became a frame emitter
 * change readable.on(readable) to emit(frame)
 */
var debug = require('debug')('noradle:frame')
  , bytes4 = new Buffer(4)
  ;

exports.writeFrame = function(stream, slotID, type, flag, body){
  // debug('before write frame', slotID, type, flag);
  var head = new Buffer(8), w1, w2;
  head.writeInt16BE(slotID, 0);
  head.writeUInt8(type, 2);
  head.writeUInt8(flag, 3);
  if (body) {
    head.writeInt32BE(body.length, 4);
    w1 = stream.write(head);
    w2 = stream.write(body);
    debug('write frame', slotID, type, flag, body.length, w1, w2);
  } else {
    head.writeInt32BE(0, 4);
    w1 = stream.write(head);
    debug('write frame', slotID, type, flag, 0, w1);
  }
};

/**
 * send its magic number to the peer
 * receive magic number of the peer
 * and then receive and parse the arriving frame
 * and make frame event to listener
 * @param c the stream/socket/connection that's just connected
 * @param magicNumber1 magic number of self to send to the peer
 * @param magicNumber2 magic number of the peer to receive for self
 * @param listener accept whole frame data, with head parsed
 */
exports.wrapFrameStream = function(c, magicNumber1, magicNumber2, listener){
  var check = false, head, slotID, type, len, body;
  if (listener) {
    c.on('frame', listener);
  }

  bytes4.writeInt32BE(magicNumber1, 0);
  c.write(bytes4);

  c.on('readable', function parse(){
    var data;

    if (!check) {
      data = c.read(4);
      if (data === null) return;
      if (data.readInt32BE(0) !== magicNumber2) {
        debug('onHandshake magic number is wrong', data.readInt32BE(0), magicNumber2);
        c.end();
        c.destroy();
        return;
      }
      check = true;
    }

    if (!head) {
      head = c.read(8);
      if (head === null) return;
      slotID = head.readUInt16BE(0);
      type = head.readUInt8(2);
      flag = head.readUInt8(3);
      len = head.readInt32BE(4);
    }

    if (len > 0 && !body) {
      body = c.read(len);
      if (body === null) return;
    }

    debug('read frame', magicNumber2, head, slotID, type, flag, len);
    c.emit('frame', head, slotID, type, flag, len, body);
    head = body = undefined;
    parse();
  });
};

