var bUnitTest = (process.argv[1] === __filename)
  , findFreeOraLink = require('./db.js')
  , CRLF = '\r\n'
  , TypeMarker = 'NodeJS Call'
  ;


function DBCall(dbuName, dbName){
  // if (dbName) return new Error('No database specified, can not be used to call store procedure!');
  this.dbuName = dbuName.toLowerCase();
  this.dbName = dbName;
  if (!this.dbName) {
    console.warn('no database name specified, use connection of default oracle database.');
  }
}

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
  return callOra(dbName, dbuName.toLowerCase(), spName.toLowerCase(), params, {}, cb);
};

function callOra(db, dbu, prog, params, headers, cb){
  var oraSock = findFreeOraLink()
    , parts = prog.split('.')
    , oraStatus
    , oraResHead2 = {}
    , resultLength
    , readBytes = 0
    , result = []
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

  if (cb) {
    // oraSock.setEncoding('utf-8');

    function writeToLength(data){
      readBytes += data.length;
      result.push(data.toString('utf-8'));
      if (readBytes === resultLength) {
        result = result.join('');
        oraSock.removeListener('data', acceptOracleResult);
        oraSock.busy = false;
        if (oraStatus >= 400 && oraStatus < 600) {
          cb(new Error({errorCode : oraStatus, message : result}));
        } else {
          cb(null, result, oraResHead2);
        }
      }
    }

    function acceptOracleResult(data){
      if (!resultLength) {
        // first data arrived
        var hLen = parseInt(data.slice(0, 5).toString('utf8'), 10)
          , oraResHead = data.slice(5, 5 + hLen - 2).toString('utf8').split(CRLF)
          , bodyChunk = data.slice(5 + hLen, data.length)
          ;
        oraStatus = parseInt(oraResHead.shift().split(' ').shift());
        oraResHead.forEach(function(nv){
          nv = nv.split(": ");
          oraResHead2[nv[0]] = nv[1]; // todo: multi occurrence headers not supported by now
        });
        resultLength = parseInt(oraResHead2['Content-Length']);
        if (!resultLength) {
          oraSock.removeListener('data', acceptOracleResult);
          oraSock.busy = false;
          cb(new Error('this version of node2oracle direct call do not support chunked transfer encoding for oracle result.'));
          return;
        }
        writeToLength(bodyChunk);
      } else {
        writeToLength(data);
      }
    }

    oraSock.on('data', acceptOracleResult);
  }
  // all standard request header info have been sent to oracle by now
  return oraSock; // so can write like http post to send lines of input to oracle
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
    var params = {
      a : ['hello world', 'so\r\nfor', 'a,b and c'],
      b : []
    };
    console.log(formatParam(params));
    var db = new DBCall('demo');
    db.call('db_src_b.example', function(err, page, headers){
      if (err) {
        console.error(err);
        process.exit(2);
      }
      var parser = require('./RSParser');
      console.log(headers);
      console.log('----');
      // console.log(page);
      console.log(parser.parse(page).test.rows[3]);
    })
  }, 3000);