var bUnitTest = (process.argv[1] === __filename)
  , EV = require('events').EventEmitter
  , mUtil = require('util')
  , formatParam = require('./util.js').formatParam
  , DBPool = require('./db3.js').DBPool
  , useBase = require('./util.js').useBase
  ;

function DBCall(dbPool, base){
  EV.call(this);
  this.dbPool = dbPool || DBPool.getFirstPool();
  this.base = base || {};
}
mUtil.inherits(DBCall, EV);

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
  useBase(this.base, params);

  if (params.x$dbu) {
    params.x$prog = prog;
  } else {
    parts = prog.split('.');
    params.x$dbu = parts.shift();
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

  this.dbPool.findFree(env, null, function(err, oraReq){
    var result = [];
    if (err) {
      console.error(err);
    }
    oraReq
      .init('DATA', params.y$hprof || '')
      .addHeaders(params, '')
      .end(function(oraRes){
        oraRes.on('data', function(data){
          result.push(data.toString('utf-8'));
          msgEmitter.emit('data');
        });
        oraRes.on('end', function(data){
          msgEmitter.emit('end');
          result = result.join('');
          cb && cb(oraRes.status, oraRes.header, result);
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