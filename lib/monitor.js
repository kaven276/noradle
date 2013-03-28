var db = require('./db.js');

var stat = {allCnt : 0, reqCnt : 0, cssCnt : 0, fbCnt : 0}
  , timeouts = db.waitTimeoutStats
  , startTime = new Date()
  , ports = {http : 0, https : 0, oracle : db.port}
  , servers = {http : null, https : null, oracle : db.server}
  , fmt = require('util').format
  , SidGuard = require('./SidGuard.js')
  ;

exports.stat = stat;
exports.ports = ports;
exports.servers = servers;

exports.showStatus = function(req, res){
  res.writeHead(200, {'Content-Type' : 'text/html', 'Transfer-Encoding' : 'chunked'});
  function w(c){
    res.write(c);
    res.write('<br/>');
  }

  res.write('<head><style>body{line-height: 1.3em;}</style></head>')

  w('Server started at ' + startTime);
  w('');

  w('[Memory Using]');
  w(fmt(process.memoryUsage()).replace(/(\d)(\d{3})(\D)/gm, '$1,$2$3').replace(/(\d)(\d{3})(\D)/gm, '$1,$2$3'));
  w('');

  w('[server listening ports and connections]');
  w(fmt('oracle: %d, %d', ports.oracle, servers.oracle && servers.oracle.connections));
  w(fmt('http:  %d, %d', ports.http, servers.http && servers.http.connections));
  w(fmt('https:  %d, %d', (ports.https || 'not used'), servers.https ? servers.https.connections : 0));
  w('');

  w('[request counters]');
  w('total requests count: ' + stat.allCnt);
  w('normal requests count: ' + stat.reqCnt);
  w('following linked css requests count: ' + stat.cssCnt);
  w('following feedback requests count: ' + stat.fbCnt);
  w('');

  w('[timeout stats]');
  w('wait free oraSock timeout count: ' + timeouts.conn);
  w('wait any response timeout count: ' + timeouts.resp);
  w('wait servlet to finish timeout count: ' + timeouts.fin);
  w('busy execution\'s socket is end in exception count: ' + timeouts.busyEnd);
  w('request canceled(not start to run at all) in waitQueue count: ' + timeouts.cancel);
  w('');

  w('[oracle server process & connection slot statistics]');
  var tBytesRead = 0
    , tBytesWritten = 0
    ;
  db.dbPool.forEach(function(rec, i){
    var c = rec.oraSock;
    tBytesRead += c.bytesRead + rec.hBytesRead;
    tBytesWritten += c.bytesWritten + rec.hBytesWritten;
    w(fmt('NO.%d (%d:%d) %s reads(%d,%d) write(%d,%d)', i, c.sid, c.serial, rec.status, c.bytesRead, c.bytesRead + rec.hBytesRead, c.bytesWritten, c.bytesWritten + rec.hBytesWritten));
  });
  w('oracle network traffic summary: ');
  w('TotalBytesRead: ' + tBytesRead + ', TotalBytesWrite: ' + tBytesWritten);
  w('');

  w('[oracle connection pool statistics]');
  w('> total connections : ' + (db.freeList.length + db.busyList.length));
  w('> free connections : ' + db.freeList.length);
  w('> quiting connections : ' + db.quitList.length);
  w('> Busy List: ' + db.busyList.length);
  db.busyList.forEach(function(rec){
    var c = rec.oraSock;
    w(fmt((new Date() - rec.date) + ' ms > %s in(sid=%d:%d, pseq=%d) ', rec.env, c.sid, c.serial, c.pseq));
  });
  w('> Wait Queue: ' + db.waitQueue.length);
  db.waitQueue.forEach(function(rec){
    w((new Date() - rec.date) + ' ms > ' + rec.env);
  });
  w('');

  w('[session and guard]');
  var gs = SidGuard.stats
    , sids = SidGuard.sidsInAll
    ;
  w('Clean(GC) Statistics:');
  w(fmt('times: %s, total(ms): %s, average(ms): %s', gs.cleans, gs.totalTime, gs.totalTime / gs.cleans));
  w('Session count by host:port :');
  Object.keys(sids).forEach(function(host){
    w(fmt('%s > %d', host, Object.keys(sids[host]).length));
  })
  w('</br/> Clean Statistics:');

  res.end();
}
