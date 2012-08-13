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
  this.old = null;
  this.time = Date.now();
}

function checkUpdate(host, bsid, guard){
  var threshold = cfg.GuardUpdateInterval * 1000;
  var sidsInHost = sidsInAll[host];
  if (!sidsInHost) {
    sidsInHost = sidsInAll[host] = {};
  }
  var rec = sidsInHost[bsid];
  if (!rec) {
    rec = sidsInHost[bsid] = new Rec();
    return rec.cur;
  }
  console.log(bsid, guard, rec);
  if (!guard) {
    throw new Error('session hijacking detected, refuse to serve this faked session.');
  }
  if (rec.cur !== guard && rec.old !== guard) {
    throw new Error('session hijacking detected, refuse to serve this faked session.');
  }
  var now = Date.now();
  if (now - rec.time > threshold) {
    rec.old = rec.cur;
    rec.cur = random();
    rec.time = now;
    return rec.cur;
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
