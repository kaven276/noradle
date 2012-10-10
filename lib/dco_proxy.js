/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-7-4
 * Time: 上午11:19
 */

var net = require('net')
  , StreamSpliter = require('./StreamSpliter.js').Class
  , utl = require('./util.js')
  , assert = require('assert')
  , exitFlag = false
  , counter = new Counter()
  , extHubSocks = []
  ;

function Counter(){
  this.onTheWay = 0;
  this.reqs = 0;
  this.fins = 0;
}
Counter.prototype.start = function(){
  this.onTheWay++;
  this.reqs++;
  console.log('counter on start %j', this);
};
Counter.prototype.finish = function(){
  this.onTheWay--;
  this.fins++;
  console.log('counter on finish %j', this);
  if (exitFlag && this.onTheWay === 0) process.exit(0);
};

utl.gracefulExit(function(){
  // stop accept new request
  // detect end of current request and then quit
  var askClosePDU = new Buffer(12);
  askClosePDU.writeInt32BE(6, 0);
  askClosePDU.writeInt32BE(0, 4);
  askClosePDU.writeInt32BE(0, 8);
  extHubSocks.forEach(function(sock){
    // tell ext-hub to half close the tcp connection
    sock.write(askClosePDU);
  });
  exitFlag = true;
  if (counter.onTheWay === 0) process.exit(0);
  var lastOnTheWayCnt = -1;
  setInterval(function(){
    if (counter.onTheWay === 0 || lastOnTheWayCnt === counter.onTheWay) {
      process.exit(counter.value);
    } else {
      lastOnTheWayCnt = counter.onTheWay;
    }
  }, 1000);
});

exports.createServer = function(handler){
  var server = net.createServer(function(extHubSock){
    console.log('connect from ext_hub');

    extHubSock.once('data', function onHandshake(data){

      // for begin of connection
      try {
        var ptoken = data.readInt32BE(0);
      } catch (e) {
        ptoken = -1;
      }
      if (ptoken !== 197610263) {
        console.warn('none ext-hub connection to out proxy attempt found');
        extHubSock.end();
        extHubSock.destroy();
        return;
      }

      // for end of connection
      (function(){
        /** @const */
        var extHubID = extHubSocks.length;
        extHubSocks.push(extHubSock);
        extHubSock.on('close', function(){
          console.log('ext-hub(%d) will not send new request, in-bound socket half closed', extHubID);
          delete extHubSocks[extHubID];
        });
      })();

      new StreamSpliter(extHubSock, 'readInt32BE', function onRequest(pdu){
        counter.start();
        if (pdu.readInt32BE(0) > 0) {
          handler(new Request(pdu, true), new Response(extHubSock, pdu.slice(0, 12)));
        } else {
          handler(new Request(pdu, false), new DummyResponse());
        }
      });

      if (data.length > 12) {
        extHubSock.emit('data', data.slice(12));
      }
    });
  });
  return new DcoWorkerProxy(server);
};

function DcoWorkerProxy(server){
  this.server = server;
}
DcoWorkerProxy.prototype.listen = function(port, host){
  this.server.listen(port, host, function(){
    console.log('worker proxy is listening at %s:%d', host || 'localhost', port);
  });
};

function Request(pdu, sync){
  this.content = pdu.slice(12);
  this.sync = sync;
}

function Response(extHubSock, header){
  this._extHubSock = extHubSock;
  this._header = header;
  this._buffer = [];
  this._length = 12;
}
Response.prototype.write = function(data){
  if (!data) return;
  if (data instanceof String) {
    data = new Buffer(data, 'utf8');
  }
  this._buffer.push(data);
  this._length += data.length;
};
Response.prototype.end = function(data){
  if (data) this.write(data);
  var header = this._header;
  header.writeInt32BE(this._length, 0);
  var extHubSock = this._extHubSock;
  extHubSock.write(header);
  this._buffer.forEach(function(buf){
    extHubSock.write(buf);
  });
  counter.finish();
};

function DummyResponse(){
}
DummyResponse.prototype.end = function(){
  assert(arguments.length === 0, 'The request require no response PDU');
  counter.finish();
};
