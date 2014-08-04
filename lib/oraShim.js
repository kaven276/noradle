/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 14-6-18
 * Time: 下午7:56
 */

/**
 * init data from oracle to nodejs
 * 0 magic number that stand for Noradle protocol
 * 4 oracle session sid
 * 8 oracle session serial#
 * 12 oracle server slot number in the management of one server_control_t record
 * 16 if primary(1) or standby database(2),
 * 20 length of oracle db global name + ',' + oracle db unique name
 * 24 oracle db global name + ',' + oracle db unique name
 */

var net = require('net')
  , C = require('./constant.js')
  , REQ_END_MARK = C.REQ_END_MARK
  , RES_END_MARK = 'EOF'
  , processes = 10
  , printRequestInfo = require('./shimServlet.js').printRequestInfo
  ;

var EXPECT_HEAD = 1
  , EXPECT_BODY = 2
  , EXPECT_RELEASE = 3
  ;

var dbUniqueNames = 'dialbook'.split(',');

dbUniqueNames.forEach(function(dbUniqueName){
  for (var i = 1; i <= processes; i++) {
    startOneOracleBG(dbUniqueName, i);
  }
});

function writeStruct(buf, arr, pos){
  pos = pos || 0;
  for (var i = 0, len = arr.length; i < len; i++) {
    buf.writeInt32BE(arr[i], pos);
    pos += 4;
  }
}

function Request(){
  this.protocol = false;
  this.hprof = false;
  this.nvp = {};
  this.body = '';
  this._header = [];
  this._body = [];
}

function startOneOracleBG(dbUniqueName, i, interval){
  var stime = Date.now()
    , reqCnt = 0
    ;
  var c = net.connect(8000, function(){
    interval && clearInterval(interval);

    // send db attrs to nodejs on the head of oraSock
    {
      // dbName, dbDomain, dbUniqueName, dbRole
      var dbNames = ['dialbook', 'noradle.com', dbUniqueName, 'PRIMARY'].join('/')
        , data = new Buffer(36 + dbNames.length)
        , lifeMin = Math.floor((Date.now() - stime) / 1000 / 60)
        ;
      // magicNum, sid, serial, spid, slot, lifeMin, reqCnt, inst, rest length
      writeStruct(data, [197610261, i, 0, i, i, lifeMin , reqCnt , -1, dbNames.length]);
      data.write(dbNames, 36, dbNames.length);
      c.write(data);
      console.log(dbNames, 'connecting');
    }
    c.setEncoding('utf8');
    initReq();

    var stage, r;

    function initReq(){
      reqCnt++;
      stage = EXPECT_HEAD;
      r = new Request();
    }

    c.on('data', function readData(data){
      switch (stage) {
        case EXPECT_HEAD:
          var pos = data.search('\r\n\r\n\r\n');
          if (~pos) {
            // has header close \r\n\r\n
            r._header.push(data.slice(0, pos));
            // console.log(_header);
            var lines = r._header.join('').split('\r\n');
            r.protocol = lines[0];
            r.hprof = lines[1];
            for (var j = 2, len = lines.length; j < len; j += 2) {
              r.nvp[lines[j]] = lines[j + 1];
            }
            stage = EXPECT_BODY;
            // console.log(protocol, hprof, nvp);
            readData(data.slice(pos + 6));
          } else {
            r._header.push(data);
          }
          return;
        case EXPECT_BODY:
          r.body = data;
          console.log('print page', i);
          printRequestInfo(r, c, function(){
            c.write(RES_END_MARK);
            stage = EXPECT_RELEASE;
          });
          break;
        case EXPECT_RELEASE:
          if (data.length === 0) {
            return;
          }
          // check if read request info completely
          if (data !== REQ_END_MARK) {
            console.log('expect REQ_END_MARK, but found', data);
            c.end();
            return;
          }
          c.write(REQ_END_MARK); // signal nodejs to safe release oraSock
          initReq();
          break;
      }
    });
    c.on('error', function(err){
      console.log('slot', i, 'error', err);
    });
    c.on('end', function(){
      console.log('slot', i, 'end');
      reconnect();
    });

    function reconnect(){
      var interval = setInterval(function(){
        startOneOracleBG(dbUniqueName, i, interval);
      }, 3000);
    }
  });
}
