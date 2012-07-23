var stat = {allCnt : 0, reqCnt : 0, cssCnt : 0, fbCnt : 0}
  , db = require('./db.js')
  , startTime = new Date
  , ports = {oracle : db.port}
  ;

exports.stat = stat;
exports.ports = ports;

exports.showStatus = function(req, res){
  res.writeHead(200, {'Content-Type' : 'text/html', 'Transfer-Encoding' : 'chunked'});
  function w(c){
    res.write(c);
    res.write('<br/>');
  }

  w('Server started at ' + startTime);
  w(JSON.stringify(ports));
  w(JSON.stringify(stat));
  w('free connection : ' + db.freeList.length);
  w('busy executions using connection : ' + db.busyList.length);
  w('request waiting for connection : ' + db.waitQueue.length);

  w('');
  w('Busy List');
  db.busyList.forEach(function(rec){
    w((new Date() - rec.date) + ' ms > ' + rec.env);
  });
  w('');
  w('Wait Queue');
  db.waitQueue.forEach(function(rec){
    w((new Date() - rec.date) + ' ms > ' + rec.env);
  });

  res.end();
}
