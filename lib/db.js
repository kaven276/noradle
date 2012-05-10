var net = require('net')
  , cfg = require('./cfg.js')
  , port = process.argv[2] || cfg.oracle_port || '1521'
  ;

var dbListener = net.createServer(function(c){
  console.log('oracle server connected, now has ' + this.connections);
  dbPool.add(c);
  c.on('end', function(){
    console.log('oracle server disconnected, now has ' + dbListener.connections);
    dbPool.del(c);
  });
  c.on('error', function(){
    console.log('oracle server connection has errors, now has ' + dbListener.connections);
  });
  c.setKeepAlive(true, 1000 * 60);
});

dbListener.listen(port, function(){
  console.log('PSP.WEB server is listening for oracle connection at port ' + port);
});


var dbPool = {
  socks : [],
  length : 0
};

dbPool.add = function(sock){
  var socks = dbPool.socks;
  var len = socks.length;
  for (var i = 0; i < len; i++) {
    if (socks[i]) continue;
    socks[i] = sock;
    sock.index = i;
    dbPool.length++;
    return;
  }
  socks.push(sock);
  sock.index = len;
  dbPool.length++;
}

dbPool.del = function(sock){
  dbPool.socks[sock.index] = null;
  dbPool.length--;
}

dbPool.findFreeOraLink = function(){
  var socks = dbPool.socks;
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
    dbPool.del(sock);
  }
  return null;
}


module.exports = exports = dbPool.findFreeOraLink;