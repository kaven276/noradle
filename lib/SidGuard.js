/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-8-10
 * Time: 上午9:18
 */

var sidsInAll = {}
  , random = require('./util.js').random
  , cfg = require('./cfg.js')
  , threshold = Math.max(cfg.GuardUpdateInterval, 15) * 1000
  ;

function Rec(cip){
  this.cur = random();
  this.old = undefined;
  this.time = Date.now();
  this.cip = cip;
}

function checkUpdate(host, bsid, guard, cip){
  var sidsInHost = sidsInAll[host]
    , now = Date.now()
    , newGuard = random()
    ;
  if (!sidsInHost) {
    sidsInHost = sidsInAll[host] = {};
  }
  var rec = sidsInHost[bsid];
  if (!rec) {
    rec = sidsInHost[bsid] = new Rec(cip);
    return rec.cur;
  }
  if (guard === rec.cur) {
    if (now - rec.time > threshold) {
      return function(){
        rec.old = rec.cur;
        rec.cur = newGuard;
        rec.time = now;
        rec.cip = cip;
        return newGuard;
      }
    } else {
      return;
    }
  } else if (guard === rec.old) {
    if ((now - rec.time) < 10 * 1000) {
      rec.cip = cip;
      return rec.cur;
    } else if (rec.cip === cip) {
      return rec.cur;
    }
  }
  console.warn('\nsession hijacking detected');
  console.warn(rec, guard);
  rec.old = '????????';
  rec.new = '????????';
  throw new Error('session hijacking detected, you are attacking or attacked, refuse to serve this maybe faked session, You can restart your browser to start a new session.');
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
