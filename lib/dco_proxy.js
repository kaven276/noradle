/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-7-4
 * Time: 上午11:19
 */
var net = require('net')
  , StreamSpliter = require('./StreamSpliter.js').Class
  ;

exports.createServer = function(handler){
  var server = net.createServer(function(extHubSock){
    console.log('connect from ext_hub');
    var spliter = new StreamSpliter(extHubSock, 'readInt32BE');
    spliter.on('message', function(pdu){
      if (pdu.readInt32BE(0) > 0) {
        handler(new Request(pdu), new Response(extHubSock, pdu.readUInt16BE(4)));
      } else {
        handler(new Request(pdu));
      }
    });
  });
  var dcoWorkerProxy = new DcoWorkerProxy(server);
  return dcoWorkerProxy;
}

function Request(pdu){
  this.content = pdu.slice(6);
}

function Response(extHubSock, traceBackSeq){
  this.extHubSock = extHubSock;
  this.traceBackSeq = traceBackSeq;
  this.buffer = [];
  this.length = 6;
}
Response.prototype.write = function(data){
  if (!data) return;
  if (data instanceof String) {
    data = new Buffer(data, 'utf8');
  }
  this.buffer.push(data);
  this.length += data.length;
}
Response.prototype.end = function(data){
  if (data) this.write(data);
  var header = new Buffer(6);
  header.writeInt32BE(this.length, 0);
  header.writeUInt16BE(this.traceBackSeq, 4);

  var extHubSock = this.extHubSock;
  extHubSock.write(header);
  this.buffer.forEach(function(buf){
    extHubSock.write(buf);
  });
}

function DcoWorkerProxy(server){
  this.server = server;
}
DcoWorkerProxy.prototype.listen = function(port, host){
  this.server.listen(port, host);
}