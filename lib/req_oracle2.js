var CRLF = '\r\n'
  , CRLF2 = '\r\n\r\n'
  , urlParse = require('url').parse
  , urlEncoded = require('./urlEncoded.js')
  , logger = require('./logger.js')
  , upload = require('./upload.js')
  , C = require('./constant.js')
  ;

function sendKVs(kvgs){
  for ns in kvgs
    }

  exports.http2oracle = function(req, rb, cookies, oraSock, next){
    var buf = []
      , hdr = req.headers
      , str
      ;

    buf.push('HTTP\r\n', rb.toOraLines(), CRLF);

    // http request headers, pass throuth to oracle except for cookies
    if (hdr['referrer']) {
      hdr['referer'] = hdr['referrer'];
      delete hdr['referrer'];
    }
    for (var n in hdr) if (n.toLowerCase !== 'cookie') buf.push('h$' + n, hdr[n]);

    // http request header's cookies
    for (n in cookies) {
      buf.push('c$' + n, cookies[n]);
    }

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
            // oraSock.write(C.REQ_END_MARK);
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
            // oraSock.write(C.REQ_END_MARK);
          });
      }
    } else {
      req.on('end', function(){
        // oraSock.write(C.REQ_END_MARK);
      });
    }
  };
