var CRLF = '\r\n'
  , CRLF2 = '\r\n\r\n'
  , urlParse = require('url').parse
  , urlEncoded = require('./urlEncoded.js')
  , logger = require('./logger.js')
  , upload = require('./upload.js')
  , C = require('./constant.js')
  , addMap = require('./util.js').addMap
  ;


exports.http2oracle = function(req, rb, cookies, oraSock, next){
  var buf = ['HTTP']
    ;

  function sendReqHead(){
    try {
      oraSock.write(buf.join(CRLF) + CRLF2);
    } catch (e) {
      console.error('write to orasock has exception.');
    }
  }

  // 1.basic http request key-values
  addMap(buf, rb, '');

  // 2. http request headers, pass throuth to oracle except for cookies
  addMap(buf, req.headers, 'h$');

  // 3. http request header's cookies
  addMap(buf, cookies, 'c$');

  // 4. parameters, for method=get from querystring, for method=post from body
  addMap(buf, urlEncoded(urlParse(req.url).query), '');

  if (req.method === 'POST') {
    var req_mime = req.headers['content-type'].split(';')[0];
    switch (req_mime) {
      case  'application/x-www-form-urlencoded' :
        req.setEncoding('utf8');
        var bdy = '';
        req.on('data', function(chunk){
          bdy += chunk;
        });
        req.on('end', function(){
          addMap(buf, urlEncoded(bdy), '');
          sendReqHead();
        });
        break;
      case 'multipart/form-data' :
        sendReqHead();
        upload(req, oraSock, next);
        break;
      default:
        sendReqHead();
        req.on('data', function(chunk){
          // sent http request body to oracle if oracle can accept
          oraSock.write(chunk);
        });
        req.on('end', function(){
          // signal final of request body or leave it to content-length
          // oraSock.write(C.REQ_END_MARK);
        });
    }
  } else {
    // http get
    sendReqHead();
    req.on('end', function(){
      // oraSock.write(C.REQ_END_MARK);
    });
  }
};
