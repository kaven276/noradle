var db = require('./db3.js')
  , DBPool = db.DBPool
  , urlParse = require('url').parse
  ;

var stat = {allCnt : 0, reqCnt : 0, cssCnt : 0, fbCnt : 0}
  , startTime = new Date()
  , fmt = require('util').format
  , SidGuard = require('./SidGuard.js')
  , stsNames = 'EMPTY,FREE,BUSY,FREEING,CLOSED,ERROR,QUIT'.split(',')
  ;

exports.stat = stat;

exports.showStatus = function(req, res){
  var url = urlParse(req.url)
    ;
  try {
    var dbPool = DBPool.pools[parseInt(url.query.port)]
  } catch (e) {
    ;
  }
  if (!dbPool) {
    dbPool = DBPool.getFirstPool();
  }
  var timeouts = dbPool.waitTimeoutStats;
  var body = [];

  function w(c){
    //res.write(c);
    //res.write('<br/>');
    body.push(c, '<br/>');
  }

  function printTR(arr){
    body.push('<tr><td>' + arr.join('</td><td>') + '</td></tr>\r\n');
  }

  w('Server started at ' + startTime);
  w('');
  w('DBPool listen at ' + dbPool.port);
  w('');

  w('[Memory Using]');
  w(fmt(process.memoryUsage()).replace(/(\d)(\d{3})(\D)/gm, '$1,$2$3').replace(/(\d)(\d{3})(\D)/gm, '$1,$2$3'));
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
  body.push('<table rules="all" style="border:1px solid;">');
  printTR(['global db name<br/>instance', 'dbniqueName<br/>dbRole',
    'slot', 'sid', 'serial#', 'spid', 'status',
    'socket<br/>count', 'request<br/>count', 'time ms<br/>(sum)', 'time ms<br/>(avg)',
    'bytesRead<br/>(this)', 'bytesRead<br/>(total)',
    'bytesWritten<br/>(this)', 'bytesWritten<br/>(total)']);
  dbPool.slots.forEach(function(rec, i){
    var c = rec.oraSock
      , bytesRead = 0
      , bytesWritten = 0
      , src = rec.oraSockAttrSet
      ;
    if (c) {
      bytesRead = c.bytesRead;
      bytesWritten = c.bytesWritten;
    }
    printTR([src.name + '.' + src.domain + '(' + src.instance + ')', src.uniqueName + '(' + src.role + ')',
      rec.slotID, src.oraSid, src.oraSerial, src.oraSpid, stsNames[rec.status],
      rec.sockCount, rec.reqCount, rec.reqTimeAccum, Math.floor(rec.reqTimeAccum / rec.reqCount),
      bytesRead, bytesRead + rec.hBytesRead,
      bytesWritten, bytesWritten + rec.hBytesWritten]);
  });
  body.push('</table>');
  w('oracle network traffic summary: ');
  w('TotalBytesRead: ' + tBytesRead + ', TotalBytesWrite: ' + tBytesWritten);
  w('');

  var busyCount = Object.keys(dbPool.busySet).length;
  w('[oracle connection pool statistics]');
  w('> total connections : ' + (dbPool.freeList.length + busyCount));
  w('> free connections : ' + dbPool.freeList.length);
  w('> Busy List: ' + busyCount);

  for (var slotId in dbPool.busySet) {
    var s = dbPool.slots[slotId];
    w(fmt((new Date() - s.bTime) + ' ms > %s in(sid=%d:%d, slotID=%d) ', s.env, s.oraSid, s.oraSerial, s.slotID));
  }
  w('> Wait Queue: ' + dbPool.waitQueue.length);
  dbPool.waitQueue.forEach(function(rec){
    w((new Date() - rec.sTime) + ' ms > ' + rec.env);
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
  });
  w('</br/> Clean Statistics:');

  var text = '<html><head><style>body{line-height: 1.3em;}td{padding:4px;}</style></head>' + body.join('') + '</body></html>';
  res.writeHead(200, {'Content-Type' : 'text/html', 'Content-Length' : (new Buffer(text)).length});
  res.end(text);
};
