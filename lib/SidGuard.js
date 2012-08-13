/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-8-10
 * Time: 上午9:18
 */

var sidsInAll = {}
  , random = require('./util.js').random
  , cfg = require('./cfg.js')
  ;

function Rec(){
  this.cur = random();
  this.old = undefined;
  this.time = Date.now();
}

function checkUpdate(host, bsid, guard){
  var threshold = cfg.GuardUpdateInterval * 1000
    , sidsInHost = sidsInAll[host]
    , now = Date.now()
    ;
  if (!sidsInHost) {
    sidsInHost = sidsInAll[host] = {};
  }
  var rec = sidsInHost[bsid];
  if (!rec) {
    rec = sidsInHost[bsid] = new Rec();
    console.log(bsid, guard, rec);
    return rec.cur;
  }
  if ((guard === rec.cur) || ( guard === rec.old && (now - rec.time) < 10 * 1000)) {
    if (now - rec.time > threshold) {
      rec.old = rec.cur;
      rec.cur = random();
      rec.time = now;
      return rec.cur;
    }
  } else {
    throw new Error('session hijacking detected, refuse to serve this faked session.');
  }
}

var stats = {
  cleans : 0,
  totalTime : 0
}

function cleanUp(){
  var now = Date.now();
  for (host in sidsInAll) {
    var sidsInHost = sidsInAll[host];
    for (bsid in sidsInHost) {
      var rec = sidsInHost[bsid];
      if (rec.time - now > 2 * 60 * 60 * 1000) {
        delete sidsInHost[bsid];
      }
    }
  }
  stats.cleans++;
  stats.totalTime += (Date.now() - now);
  setTimeout(cleanUp, cfg.GuardCleanInterval * 60000);
}
cleanUp();


exports.checkUpdate = checkUpdate;
exports.sidsInAll = sidsInAll;
exports.stats = stats;
