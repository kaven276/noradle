var CRLF = '\r\n'
  , CRLF2 = '\r\n\r\n'
  , CRLF3 = '\r\n\r\n\r\n'
  , urlParse = require('url').parse
  , urlEncoded = require('./urlEncoded.js')
  , logger = require('./logger.js')
  , upload = require('./upload.js')
  , C = require('./constant.js')
  , addMap = require('./util.js').addMap
  , REQ_END_MARK = require('./constant.js').REQ_END_MARK
  ;


exports.http2oracle = function(req, rb, cookies, oraSock, next){
  var buf = ['HTTP', rb.y$hprof || '']
    ;

  function sendReqHead(){
    try {
      oraSock.write(buf.join(CRLF) + CRLF3);
    } catch (e) {
      console.error('write to orasock has exception.');
    }
  }

  function end(){
    // oraSock.write(REQ_END_MARK);
  }

  // 1. http request headers, pass throuth to oracle except for cookies
  if ("h$" in rb) {
    delete rb.h$;
  } else {
    addMap(buf, req.headers, 'h$');
  }

  // 2. http request header's cookies
  if ("c$" in rb) {
    delete rb.c$;
  } else {
    addMap(buf, cookies, 'c$');
  }

  // 3.basic http request key-values
  var parts = rb.x$prog.split('.');
  if (parts.length === 1) {
    rb.x$pack = '';
    rb.x$proc = parts[0];
  } else {
    rb.x$pack = parts[0];
    rb.x$proc = parts[1];
  }
  addMap(buf, rb, '');

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
          end();
        });
        break;
      case 'multipart/form-data' :
        sendReqHead();
        upload(req, oraSock, next);
        end();
        break;
      default:
        sendReqHead();
        req.on('data', function(chunk){
          // sent http request body to oracle if oracle can accept
          oraSock.write(chunk);
        });
        req.on('end', function(){
          // signal final of request body or leave it to content-length
          end();
        });
    }
  } else {
    // http get
    sendReqHead();
    //console.log(req);
    end();
    req.on('close', function(){
      console.log('client req close');
    });
  }
};
