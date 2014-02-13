var bUnitTest = (process.argv[1] === __filename)
  , DBInMgr
  , CRLF = '\r\n'
  , TypeMarker = 'DATA'
  , EV = require('events').EventEmitter
  , mUtil = require('util')
  , logger = require('./logger.js').msgStream
  , C = require('./constant.js')
  ;

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
    dbName = this.dbName;
    dbuName = this.dbuName;
    spName = prog;
    if (params instanceof Function) {
      cb = params;
      params = {};
    } else if (!params) {
      params = {};
    }
  }

  var env = dbuName + '.' + spName + '@' + dbName;
  DBInMgr.findFreeOraSockThen(env, null, function(oraSock, busyRec){
    console.log('\nfind free\n');
    if (oraSock) {
      callOra.call(self, dbName, dbuName.toLowerCase(), spName.toLowerCase(), params, {}, cb, msgEmitter, oraSock, busyRec);
    } else {
      cb(503, new Error('finding free oracle connection timeout'));
    }
  });
  return msgEmitter;
};

/**
 * standard and normalized API call from NodeJS to Oracle PL/SQL
 * @param db
 * @param dbu
 * @param prog
 * @param params
 * @param headers
 * @param cb
 * @return {*}
 */
function callOra(db, dbu, prog, params, headers, cb, msgEmitter, oraSock, busyRec){
  var self = this
    , parts = prog.split('.')
    , oraStatus
    , oraResHead2
    , resultLength
    , readBytes = 0
    , result = []
    ;
  oraSock.write(TypeMarker + CRLF); // mark start of node2oracle direct call
  oraSock.write(dbu + CRLF);
  oraSock.write(prog + CRLF);
  oraSock.write(parts.pop() + CRLF);
  oraSock.write((parts.pop() || '') + CRLF);
  oraSock.write(CRLF); // for empty headers
  oraSock.write(formatParam(params));
  oraSock.write(CRLF); // for end marker of params

  /**
   * for the request/response type
   * will emit received data chunks as data event, and emit end, error events
   * @param data one chunk received from oracle database
   */
  function writeToLength(data){
    readBytes += data.length;
    result.push(data.toString('utf-8'));
    msgEmitter.emit('data', data);
    if (readBytes === resultLength) {
      result = result.join('');
      DBInMgr.pushBackToFreelist(oraSock, busyRec);
      cb && cb(oraStatus, result, oraResHead2);
      msgEmitter.emit('end', null);
    }
  }

  function acceptOracleResult(data){
    logger(data.length, 'accept data length');
    if (oraResHead2) {
      writeToLength(data, 0);
      return;
    }
    // first data arrived
    var hLen = parseInt(data.slice(0, 5).toString('utf8'), 10)
      , oraResHead = data.slice(5, 5 + hLen - 2).toString('ascii').split(CRLF)
      , bodyChunk = data.slice(5 + hLen, data.length)
      ;
    oraStatus = parseInt(oraResHead.shift().split(' ').shift());
    oraResHead2 = {};
    oraResHead.forEach(function(nv){
      nv = nv.split(": ");
      oraResHead2[nv[0]] = nv[1]; // todo: multi occurrence headers not supported by now
    });
    logger(oraResHead || 'no result header got');
    resultLength = parseInt(oraResHead2['Content-Length']);
    if (!resultLength) {
      DBInMgr.pushBackToFreelist(oraSock, busyRec);
      if (resultLength === 0) {
        cb(null, '');
      } else {
        cb(new Error('this version of node2oracle direct call do not support chunked transfer encoding for oracle result.'));
      }
      return;
    }
    writeToLength(bodyChunk);
  }

  oraSock.on('data', acceptOracleResult);
}

function formatParam(params){
  var lines = []
    , vals
    ;
  for (var n in params) {
    if (!(params[n] instanceof Array)) params[n] = [params[n]];
    vals = params[n];
    vals.forEach(function(item, i){
      vals[i] = encodeURIComponent(item); // todo : maybe convert "," and "\r\n" is well enough
    });
    lines.push(n, vals.join(','));
  }
  if (lines.length) {
    return lines.join(CRLF) + CRLF;
  } else {
    return '';
  }
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