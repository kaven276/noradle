var net = require('net');
var DBListener = net.createServer(function(c) {
    console.log('server connected ' + this.connections);
    db.add(c);
    c.setEncoding('utf8');
    c.on('end',
    function() {
        console.log('server disconnected ' + this.connections);
        db.del(c);
    });
});
DBListener.listen(1522,
function() {
    console.log('node2psp server listening');
});

var db = {}
db.socks = [];
db.length = 0;
db.add = function(sock) {
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
db.del = function(sock) {
    db.socks[sock.index] = null;
    db.length--;
}
db.findFreeOraLink = function() {
    var socks = db.socks;
    var len = socks.length;
    for (var i = 0; i < len; i++) {
        console.log('%d. sock is ' + (socks[i] ? !!socks[i].busy: 'nosock'), i);
        if (socks[i] && !!socks[i].busy) continue;
        return socks[i];
    }
    return null;
}

module.exports = exports = db.findFreeOraLink;