/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-25
 * Time: 下午2:53
 */

var bUnitText = (process.argv[1] === __filename)
  , EV = require('events').EventEmitter
  , util = require('util')
  ;

function ByLeadingSize(stream, method, callback){
  var self = this
    , lenMethod
    , dueLen = false
    , message
    , halfLen
    , halfHdr
    ;
  EV.call(this);
  callback && this.on('message', callback);

  method = method || 'readUInt32BE';
  lenMethod = Buffer.prototype[method];
  stream.on('data', handler);

  function handler(data){
    if (!dueLen) {

      if (halfHdr) {
        var newData = new Buffer(halfHdr.length + data.length);
        halfHdr.copy(newData);
        data.copy(newData, halfHdr.length);
        data = newData;
        halfHdr = null;
      }

      try {
        dueLen = Math.abs(lenMethod.call(data, 0));
      } catch (e) {
        halfHdr = data;
        return;
      }

      console.log('message length = %d', dueLen);

      if (dueLen === 0) {
        self.emit('end', null);
        stream.removeListener('data', handler);
        return;
      }
      message = new Buffer(dueLen);
      halfLen = 0;
    }
    var lackLen = dueLen - halfLen;
    var restLen = data.length - lackLen;
    if (restLen >= 0) {
      data.copy(message, halfLen, 0, lackLen);
      self.emit('message', message);
      dueLen = false;
      if (restLen > 0)
        handler(data.slice(lackLen));
    } else {
      data.copy(message, halfLen);
      halfLen += data.length;
    }
  }
}
util.inherits(ByLeadingSize, EV);

exports.Class = ByLeadingSize;

if (bUnitText) {
  var net = require('net');
  (function(){
    var server = net.createServer(function(c){
      console.log('client connected.');
      var spliter = new ByLeadingSize(c, 'readInt32BE');
      spliter.on('test', function(str){
        console.log(str);
      })
      spliter.on('message', function(msg){
        console.log('received message : ' + msg.toString('utf8', 4));
      });
    });
    server.listen(3000);
    var socket = net.Socket();
    socket.connect(3000, function(){
      var repeat = 3;
      var str = 'Li Yong';
      var bigBuf = new Buffer(11 * 3);
      for (var i = 0; i < 3; i++) {
        bigBuf.writeUInt32BE(11, i * 11);
        bigBuf.write(str, i * 11 + 4);
      }
      socket.write(bigBuf);

      var len = str.length * repeat + 4;
      var buf = new Buffer(4);
      buf.writeUInt32BE(len, 0);
      socket.write(buf);
      var intervalID = setInterval(function(){
        if (--repeat === 0) {
          clearInterval(intervalID);
        }
        socket.write(str);
      }, 1000);
    })
  })();
}
