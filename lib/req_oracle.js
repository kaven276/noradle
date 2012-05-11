var CRLF = '\r\n'
  , CRLF2 = '\r\n\r\n'
  , urlParse = require('url').parse
  , urlEncoded = require('./urlEncoded.js')
  , logger = require('./logger.js')
  , upload = require('./upload.js')
  , endMark = '--the end--' + CRLF
  ;

exports.http2oracle = function(req, oraSock, rb, next){
  var buf = []
    , hdr = req.headers
    , str
    ;

  buf.push(endMark, rb.toOraLines(), CRLF);

  // http request headers, pass throuth to oracle except for cookies
  var ora_head = [];
  if (hdr['referrer']) {
    hdr['referer'] = hdr['referrer'];
    delete hdr['referrer'];
  }
  for (var n in hdr) if (n.toLowerCase !== 'cookie') ora_head.push(n, hdr[n]);
  str = ora_head.join(CRLF);
  buf.push(str, str ? CRLF2 : CRLF);

  // http request header's cookies
  var ora_cookie = [];
  if (hdr.cookie) {
    hdr.cookie.split(/[;,] */).forEach(function(cookie){
      var nv = cookie.split('=');
      ora_cookie.push(nv[0], nv[1]);
    });
  }
  str = ora_cookie.join(CRLF);
  buf.push(str, str ? CRLF2 : CRLF);

  // parameters, for method=get from querystring, for method=post from body
  str = urlEncoded(urlParse(req.url).query);
  buf.push(str, str ? CRLF2 : CRLF);

  try {
    oraSock.write(buf.join(''));
  } catch (e) {
    console.error('write to orasock has exception.');
  }

  logger.oraReq(buf);

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
          oraSock.write(urlEncoded(bdy) + CRLF2);
        });
        break;
      case 'multipart/form-data' :
        upload(req, oraSock, next);
        break;
      default:
        req.on('data', function(chunk){
          // sent http request body to oracle if oracle can accept
          oraSock.write(chunk);
        });
        req.on('end', function(){
          // signal final of request body or leave it to content-length
        });
    }
  }
};
