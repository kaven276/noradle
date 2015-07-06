var bUnitTest = (process.argv[1] === __filename)
  , EV = require('events').EventEmitter
  , mUtil = require('util')
  , formatParam = require('./util/util.js').formatParam
  , DBPool = require('./DBDriver.js').DBPool
  , useBase = require('./util/util.js').useBase
  , parse = require('./RSParser.js').rsParse
  , itemSep = String.fromCharCode(30) + '\n'
  ;

function DBCall(dbPool, base){
  EV.call(this);
  this.dbPool = dbPool || DBPool.getFirstPool();
  this.base = base || {};
}
mUtil.inherits(DBCall, EV);

DBCall.prototype.call = function(prog, params, body, cb){
  if (arguments.length === 3 && arguments[2] instanceof Function) {
    cb = body;
    body = undefined;
  }
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

  if (body) {
    if (body instanceof Buffer) {
      ;
    } else if (typeof body === 'string') {
      body = new Buffer(body);
    } else {
      body = new Buffer(JSON.stringify(body));
    }
  }

  var env = params.x$dbu + '.' + params.x$prog + '@' + params.x$db
    , me = this
    ;

  function listen(){

    me.dbPool.findFree(env, null, function(err, oraReq){
      var result = [];
      if (err) {
        console.error(err);
      }
      oraReq
        .init('DATA', params.y$hprof || '')
        .addHeaders(params, '')
        .write(body)
        .end(onEnd)
      ;
      function onEnd(oraRes){
        oraRes.on('data', function(data){
          result.push(data.toString('utf-8'));
          msgEmitter.emit('data', data);
        });
        oraRes.on('end', function(){
          msgEmitter.emit('end');
          result = result.join('');
          if (params.__parse) {
            switch ((oraRes.headers['Content-Type'] || '').split(';')[0]) {
              case 'text/items':
                result = result.split(itemSep);
                result.pop();
                break;
              case 'text/resultsets':
                result = parse(result);
                break;
            }
          }
          if (!cb) {
            return;
          }
          if (params.__repeat) {
            switch (oraRes.status) {
              case 200:
                process.nextTick(listen);
                cb(oraRes.status, oraRes.headers, result);
                break;
              case 504:
                // monitor new message timeout
                process.nextTick(listen);
                return;
              default:
                params.__ignore_error || cb(oraRes.status, oraRes.headers, result);
                setTimeout(listen, 3000);
                return;
            }
          } else {
            cb(oraRes.status, oraRes.headers, result);
          }
        });
      }
    });
  }

  if (params.__parallel) {
    for (var i = 0, len = params.__parallel; i < len; i++) {
      params.__log && console.log('start callout listener', params.x$dbu + '.' + params.x$prog, i + 1);
      listen();
    }
  } else if (params.__interval) {
    params.__log && console.log('start interval caller', params.x$dbu + '.' + params.x$prog, params.__interval);
    setInterval(listen, params.__interval);
    listen();
  } else {
    listen();
  }

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