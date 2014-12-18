/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 14-10-20
 * Time: 下午4:58
 */

var sessionStore = {}

var sessionCount = 0;

function Session(){
  this.store = {};
  this.LAT = Date.now();
  sessionCount++;
}
Session.prototype.set = function(name, value){
  this.store[name] = value;
  // todo: write to log;
};
function createSession(app, bsid){
  try {
    return sessionStore[app][bsid] = new Session();
  } catch (e) {
    sessionStore[app] = {};
    return sessionStore[app][bsid] = new Session();
  }
}

function destroySession(app, bsid){
  try {
    delete sessionStore[app][bsid];
    sessionCount--;
  } catch (e) {
    ;
  }
}

exports.create = createSession;
exports.destroy = destroySession;

// for sending app session data to oracle
exports.gets = function(app, bsid){
  try {
    return sessionStore[app][bsid];
  } catch (e1) {
    return false;
    try {
      // new bsid
      return sessionStore[app][bsid] = new Session();
    } catch (e2) {
      // new app
      sessionStore[app] = {};
      return sessionStore[app][bsid] = new Session();
    }
  }
};

function clearTimeout(){
  var now = Date.now()
    , timeout = 60 * 60 * 1000
    , low = now - timeout
    ;
  if (sessionCount < 80000) return;
  for (app in sessionStore) {
    var appSess = sessionStore[app];
    for (bsid in appSess) {
      var sess = appSess[bsid]
      if (sess.LAT < low || sess.LAT < now - (sess.s$TIMEOUT || 0) * 1000) {
        delete appSess[bsid];
        sessionCount--;
      }
    }
  }
}

exports.clearTimeout = clearTimeout;
exports.db = sessionStore;
exports.sessionCount = function(){
  return sessionCount;
};

var inspect = require('util').inspect;

setInterval(function(){
  console.log(inspect(sessionStore, {depth : 3, color : true}));
}, 300000);

setInterval(clearTimeout, 3 * 60 * 1000);