/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 14-10-20
 * Time: 下午4:58
 */

var sessionStore = {}

function Session(){
  this.store = {};
  this.LAT = Date.now();
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
  for (app in sessionStore) {
    var appSess = sessionStore[app];
    for (bsid in appSess) {
      var session = appSess[bsid]
      if (sess.LAT < low || sess.LAT < now - (sess.s$TIMEOUT || 0) * 1000) {
        delete appSess[bsid];
      }
    }
  }
}

var inspect = require('util').inspect;

setInterval(function(){
  console.log(inspect(sessionStore, {depth : 3, color : true}));
}, 3000);

setInterval(clearTimeout, 3 * 60 * 1000);