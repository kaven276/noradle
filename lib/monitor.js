var stat = {allCnt : 0, reqCnt : 0, cssCnt : 0, fbCnt : 0}
  , db = require('./db.js')
  , timeouts = db.waitTimeoutStats
  , startTime = new Date
  , ports = {oracle : db.port}
  , fmt = require('util').format
  ;

exports.stat = stat;
exports.ports = ports;

exports.showStatus = function(req, res){
  res.writeHead(200, {'Content-Type' : 'text/html', 'Transfer-Encoding' : 'chunked'});
  function w(c){
    res.write(c);
    res.write('<br/>');
  }

  res.write('<head><style>body{line-height: 1.3em;}</style></head>')

  w('Server started at ' + startTime);
  w('');

  w('[server listening ports]');
  w('oracle: ' + ports.oracle);
  w('http: ' + ports.http);
  w('https: ' + (ports.https || 'not used'));
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
  w('wait following css/feedback request to arrive timeout count: ' + timeouts.follow);
  w('busy execution\'s socket is end in exception count: ' + timeouts.busyEnd);
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

  res.end();
}
