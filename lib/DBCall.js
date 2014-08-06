var bUnitTest = (process.argv[1] === __filename)
  , DBInMgr
  , EV = require('events').EventEmitter
  , mUtil = require('util')
  , formatParam = require('./util.js').formatParam
  ;

function DBCall(dbuName, dbName){
  EV.call(this);
  // if (dbName) return new Error('No database specified, can not be used to call store procedure!');
  this.dbuName = dbuName && dbuName.toLowerCase();
  this.dbName = dbName;
  if (!this.dbName) {
    console.warn('no database name specified, use connection of default oracle database.');
  }
}
mUtil.inherits(DBCall, EV);

DBCall.init = function(setting){
  require('./util.js').override2(require('./cfg.js'), setting || {});
  DBInMgr = require('./db.js');
  console.log('listening for oracle reverse connect');
};

DBCall.prototype.call = function(prog, params, cb){
  var parts
    , msgEmitter = new EV() // maybe oraSock on data or new msg in message stream
    ;

  if (!prog instanceof String) {
    cb(new Error('specify prog(first arg) as pure pl/sql stored procedure name, do not use array for dbName or dbuName'));
    return;
  }

  if (params instanceof Function) {
    cb = params;
    params = {};
  } else if (!params) {
    params = {};
  }

  params.x$db = this.dbName;
  if (this.dbuName) {
    params.x$dbu = this.dbuName;
    params.x$prog = prog;
  } else {
    parts = prog.split('.');
    params.x$db = parts.shift();
    params.x$prog = parts.join('.');
  }
  parts = params.x$prog.split('.');
  if (parts.length === 1) {
    params.x$pack = '';
    params.x$proc = parts[0];
  } else {
    params.x$pack = parts[0];
    params.x$proc = parts[1];
  }

  var env = params.x$dbu + '.' + params.x$prog + '@' + params.x$db;

  DBInMgr.findFree(env, null, function(err, oraReq){
    var result = [];
    if (err) {
      console.error(err);
    }
    oraReq
      .init('DATA', params.y$hprof || '')
      .addHeaders(params, '')
      .end(function(oraRes){
        console.log(oraRes.status, oraRes.headers);
        oraRes.on('data', function(data){
          result.push(data.toString('utf-8'));
          msgEmitter.emit('data');
        });
        oraRes.on('end', function(data){
          msgEmitter.emit('end');
          result = result.join('');
          cb && cb(oraRes.status, result, oraRes.header);
        });
      });
  });
  return msgEmitter;
};

exports.Class = DBCall;

// Unit Test
(function(){
  if (!bUnitTest) return;

  switch (1) {

    case 1:
      var params = {
        a : ['hello world', 'so\r\nfor', 'a,b and c'],
        b : []
      };
      console.log(formatParam(params));
      break;

  }
})();