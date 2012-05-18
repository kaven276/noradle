var bUnitTest = (process.argv[1] === __filename)
  , findFreeOraLink = require('./db.js')
  , CRLF = '\r\n'
  , TypeMarker = 'NodeJS Call'
  , EV = require('events').EventEmitter
  , mUtil = require('util')
  , logger = require('./logger.js').msgStream
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
DBCall.evDBMsg = 'message';
mUtil.inherits(DBCall, EV);

DBCall.prototype.call = function(prog, params, cb){
  var dbName
    , dbuName
    , spName
    , parts
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
  return callOra.call(this, dbName, dbuName.toLowerCase(), spName.toLowerCase(), params, {}, cb);
};

function callOra(db, dbu, prog, params, headers, cb){
  var oraSock = findFreeOraLink()
    , self = this
    , parts = prog.split('.')
    , oraStatus
    , oraResHead2
    , resultLength
    , readBytes = 0
    , result = []
    , mimeType
    , bMsgStream
    , remained = []
    , msgSectLen
    , accSectLen
    , msgEmitter = new EV() // maybe oraSock on data or new msg in message stream
    ;
  oraSock.busy = true;
  oraSock.write(TypeMarker + CRLF); // mark start of node2oracle direct call
  oraSock.write(dbu + CRLF);
  oraSock.write(prog + CRLF);
  oraSock.write(parts.pop() + CRLF);
  oraSock.write((parts.pop() || '') + CRLF);
  oraSock.write(CRLF); // for empty headers
  oraSock.write(formatParam(params));
  oraSock.write(CRLF); // for end marker of params

  if (true) {

    function writeToLength(data){
      readBytes += data.length;
      result.push(data.toString('utf-8'));
      msgEmitter.emit('data', data);
      if (readBytes === resultLength) {
        result = result.join('');
        oraSock.removeListener('data', acceptOracleResult);
        oraSock.busy = false;
        if (oraStatus >= 400 && oraStatus < 600) {
          var err = new Error({errorCode : oraStatus, message : result});
          cb && cb(err);
          msgEmitter.emit('error', err);
        } else {
          cb && cb(null, result, oraResHead2);
          msgEmitter.emit('end', null);
        }
      }
    }

    function parseStream(data, startPos){
      if (!data || data.length === 0)
        return;
      var endPos, msg;
      if (!msgSectLen) {
        msgSectLen = data.readUInt32BE(startPos, true);
        startPos += 4;
        accSectLen = 0;
      }
      endPos = startPos + (msgSectLen - accSectLen);
      logger(data.length, data.toString(), startPos, endPos, accSectLen, msgSectLen);
      if (data.length >= endPos) {
        remained.push(data.toString('utf8', startPos, endPos));
        msg = remained.join('');
        cb && cb(null, msg);
        msgEmitter.emit('message', msg);
        self.emit(DBCall.evDBMsg, msg);
        remained = [];
        msgSectLen = 0;
        if (data.length > endPos)
          parseStream(data, endPos);
      } else {
        remained.push(data.toString('utf8', startPos));
        accSectLen += (data.length - startPos);
      }
    }

    function acceptOracleResult(data){
      logger(data.length, 'accept data length');
      if (!oraResHead2) {
        // first data arrived
        var hLen = parseInt(data.slice(0, 5).toString('utf8'), 10)
          , oraResHead = data.slice(5, 5 + hLen - 2).toString('utf8').split(CRLF)
          , bodyChunk = data.slice(5 + hLen, data.length)
          ;
        oraStatus = parseInt(oraResHead.shift().split(' ').shift());
        oraResHead2 = {};
        oraResHead.forEach(function(nv){
          nv = nv.split(": ");
          oraResHead2[nv[0]] = nv[1]; // todo: multi occurrence headers not supported by now
        });
        logger(oraResHead2);
        mimeType = oraResHead2['Content-Type'];
        bMsgStream = !mimeType.indexOf('text/noradle.msg.stream');
        if (bMsgStream) {
          oraSock.on('end', function(){
            cb && cb(null, null); // signal end of message stream
            msgEmitter.emit('end', null);
          });
        } else {
          resultLength = parseInt(oraResHead2['Content-Length']);
        }
        if (!bMsgStream && !resultLength) {
          oraSock.removeListener('data', acceptOracleResult);
          oraSock.busy = false;
          cb(new Error('this version of node2oracle direct call do not support chunked transfer encoding for oracle result.'));
          return;
        }
        if (bMsgStream)
          parseStream(bodyChunk);
        else
          writeToLength(bodyChunk);
      } else {
        if (bMsgStream)
          parseStream(data, 0);
        else
          writeToLength(data);
      }

    }

    oraSock.on('data', acceptOracleResult);
  }

// all standard request header info have been sent to oracle by now
  return msgEmitter; // so can write like http post to send lines of input to oracle
}

function formatParam(params){
  var lines = []
    , vals
    ;
  for (var n in params) {
    if (!params[n] instanceof Array) params[n] = [params[n]];
    vals = params[n];
    vals.forEach(function(item, i){
      vals[i] = encodeURIComponent(item); // todo : maybe convert "," and "\r\n" is well enough
    });
    lines.push(n, vals.join(','));
  }
  return lines.join(CRLF);
}

// Unit Test
setTimeout(
  function(){
    if (!bUnitTest) return;

    var db = new DBCall('demo', 'theOnlyDB')
      , returnEmitter
      ;
    db.on(DBCall.evDBMsg, function(msg){
      console.log(msg, 'in DBCall instance event');
    });

    switch (3) {

      case 1:
        var params = {
          a : ['hello world', 'so\r\nfor', 'a,b and c'],
          b : []
        };
        console.log(formatParam(params));
        break;

      case 2: // call for result sets
        returnEmitter = db.call('db_src_b.example', function(err, page, headers){
          if (err) {
            console.error(err);
            process.exit(2);
          }
          var parser = require('./RSParser');
          console.log(headers);
          console.log('----');
          // console.log(page);
          console.log(parser.parse(page).test.rows[3]);
        });
        break;

      case 3: // call for continuously message stream, one message one emit or one callback
        returnEmitter = db.call('callout_broker_h.emit_messages', function(err, msg){
          if (err) {
            console.error(err);
            process.exit(2);
          } else {
            console.log((msg + ' in callback' ) || 'The End');
          }
        });
        returnEmitter.on('message',
          function(msg){
            console.log(msg, ' in returnEmitter');
          });
        returnEmitter.on('end', function(){
          console.log('End of returnEmitter');
        });
        break;
    }
  }, 3000);