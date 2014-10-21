/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 14-10-20
 * Time: 下午4:58
 */

var sessionStore = {}

function Session(){
  this.store = {};
}
Session.prototype.set = function(name, value){
  this.store[name] = value;
  // todo: write to log;
};

exports.create = function(app, bsid){
  try {
    return sessionStore[app][bsid] = new Session();
  } catch (e) {
    sessionStore[app] = {};
    return sessionStore[app][bsid] = new Session();
  }
};

// for sending app session data to oracle
exports.gets = function(app, bsid){
  try {
    return sessionStore[app][bsid];
  } catch (e1) {
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
