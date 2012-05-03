var net = require('net');
var cfg = require('./cfg.js');
var DBListener = net.createServer(function(c){
  console.log('oracle server connected, now has ' + this.connections);
  db.add(c);
  c.on('end',
    function(){
      console.log('oracle server disconnected, now has ' + DBListener.connections);
      db.del(c);
    });
  c.on('error',
    function(){
      console.log('oracle server connection has errors, now has ' + DBListener.connections);
    });
  c.setKeepAlive(true, 1000 * 60);
});
var port = process.argv[2] || cfg.oracle_port || '1521';
DBListener.listen(process.argv[2] || cfg.oracle_port,
  function(){
    console.log('PSP.WEB server is listening for oracle connection at port ' + port);
  });

var db = {}
db.socks = [];
db.length = 0;
db.add = function(sock){
  var socks = db.socks;
  var len = socks.length;
  for (var i = 0; i < len; i++) {
    if (socks[i]) continue;
    socks[i] = sock;
    sock.index = i;
    db.length++;
    return;
  }
  socks.push(sock);
  sock.index = len;
  db.length++;
}
db.del = function(sock){
  db.socks[sock.index] = null;
  db.length--;
}
db.findFreeOraLink = function(){
  var socks = db.socks;
  var sock;
  var len = socks.length;
  for (var i = 0; i < len; i++) {
    sock = socks[i];
    if (!sock || !!sock.busy) continue;
    if (sock._handle) return socks[i];
    try {
      console.log(new Date());
      console.log('sock is free but has no right _handle');
      sock.end();
    } catch (e) {
      console.log('empty handle socket end failed.');
    }
    db.del(sock);
  }
  return null;
}

module.exports = exports = db.findFreeOraLink;