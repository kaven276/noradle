var bUnitTest = (process.argv[1] === __filename)
  , DBInMgr
  , findFreeOraSockThen
  , CRLF = '\r\n'
  , CRLF2 = '\r\n\r\n'
  , CRLF3 = '\r\n\r\n\r\n'
  , endMark = 'EOF'
  , EV = require('events').EventEmitter
  , mUtil = require('util')
  , logger = require('./logger.js').msgStream
  , C = require('./constant.js')
  , addMap = require('./util.js').addMap
  , formatParam = require('./util.js').formatParam
  , dao = require('./dao.js')
  ;

function ResHeader(data){
  var hLen = parseInt(data.slice(0, 5).toString('utf8'), 10)
    , oraResHead = data.slice(5, 5 + hLen - 2).toString('ascii').split(CRLF)
    , header = {}
    ;
  this.status = parseInt(oraResHead.shift().split(' ').shift());
  this.bodyChunk = data.slice(5 + hLen, data.length);
  oraResHead.forEach(function(nv){
    nv = nv.split(": ");
    header[nv[0]] = nv[1]; // todo: multi occurrence headers not supported by now
  });
  this.header = header;
}

function DBCall(dbuName, dbName){
  EV.call(this);
  // if (dbName) return new Error('No database specified, can not be used to call store procedure!');
  this.dbuName = dbuName.toLowerCase();
  this.dbName = dbName;
  if (!this.dbName) {
    console.warn('no database name specified, use connection of default oracle database.');
  }
}

DBCall.init = function(setting){
  require('./util.js').override2(require('./cfg.js'), setting || {});
  findFreeOraSockThen = require('./db.js').findFreeOraSockThen;
  DBInMgr = require('./db.js');
  console.log('listening for oracle reverse connect');
};

DBCall.evDBMsg = 'message';
mUtil.inherits(DBCall, EV);

DBCall.prototype.call = function(prog, params, cb){
  var dbName
    , dbuName
    , spName
    , parts
    , msgEmitter = new EV() // maybe oraSock on data or new msg in message stream
    , self = this
    ;
  if (!this.dbuName) {
    dbName = this.dbName;
    parts = prog.split('.');
    dbuName = parts.shift();
    spName = parts.join('.');
  } else {
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
    params.x$db = this.dbName
    params.x$dbu = this.dbuName;
    params.x$prog = prog;
    var parts = params.x$prog.split('.');
    if (parts.length === 1) {
      params.x$pack = '';
      params.x$proc = parts[0];
    } else {
      params.x$pack = parts[0];
      params.x$proc = parts[1];
    }
  }

  var env = params.x$dbu + '.' + params.x$prog + '@' + params.x$db;
  findFreeOraSockThen(env, null, function(err, oraSock, slotID, freeCB){
    if (err) {
      cb(503, new Error('finding free oracle connection timeout'));
    }
    callOra.call(self, params, {}, cb, msgEmitter, oraSock, slotID, freeCB);
  });
  return msgEmitter;
};

/**
 * standard and normalized API call from NodeJS to Oracle PL/SQL
 * process actual on-wire jobs for every request/response pair
 */
function callOra(params, headers, cb, msgEmitter, oraSock, slotID, freeCB){
  var oraRes
    , resultLength
    , readBytes = 0
    , result = []
    , buf = ['DATA', params.y$hprof || '']
    ;

  addMap(buf, formatParam(params), '');
  oraSock.write(buf.join(CRLF) + CRLF3);

  oraSock.on('data', function(data){
    if (!oraRes) {
      // first data arrived
      oraRes = new ResHeader(data);
      data = oraRes.bodyChunk;
      resultLength = parseInt(oraRes.header['Content-Length']);
      if (resultLength === 0) {
        freeCB(null);
        cb(null, '');
        return;
      }
    }
    var bLen = data.length, vFin;
    if (resultLength) {
      readBytes += bLen;
      vFin = (readBytes === resultLength)
    } else {
      vFin = (data.slice(bLen - endMark.length).toString('utf8') === endMark);
      vFin && (data = data.slice(0, bLen - endMark.length));
    }
    result.push(data.toString('utf-8'));
    msgEmitter.emit('data', data);
    if (vFin) {
      result = result.join('');
      freeCB(null);
      cb && cb(oraRes.status, result, oraRes.header);
      msgEmitter.emit('end', null);
    }
  });
}

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