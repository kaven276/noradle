/**
 * Created by cuccpkfs on 15-6-4.
 */

var EE = require('events').EventEmitter
  , cssBuffer = {}
  , debug = require('debug')('noradle:CSS')
  , C = require('../constant.js')
  ;

function CSSItem(status, headers){
  this.status = status;
  this.headers = headers;
  this.chunks = [];
}

exports.filter = function CSS(oraRes){
  var cssmd5 = oraRes.headers['x-css-md5']
    , count = 0
    , ee = new EE()
    ;

  if (!cssmd5) {
    return oraRes;
  }
  debug('store CSS(%s)', cssmd5);

  cssItem = cssBuffer[cssmd5] = new CSSItem(oraRes.status, {
    'ETag' : '"' + cssmd5 + '"',
    'Content-Type' : 'text/css',
    'Cache-Control' : 'max-age=60000'
  });

  oraRes.on('data', function(data, type){
    switch (type) {
      case C.BODY_FRAME:
        ee.emit('data', data, C.BODY_FRAME);
        break;
      case C.STYLE_FRAME:
        cssItem.chunks.push(data);
        count += data.length;
        break;
    }
  });
  oraRes.on('end', function(){
    debug('stored css(%s) length=%d', cssmd5, count);
    cssItem.headers['Content-Length'] = count;
    ee.emit('end');
  });

  return ee;

};

exports.use = function(res, cssmd5){
  debug('use CSS(%s)', cssmd5);
  var cssItem = cssBuffer[cssmd5];
  if (cssItem) {
    delete cssBuffer[cssmd5];
    res.writeHead(cssItem.status, cssItem.headers);
    cssItem.chunks.forEach(function(chunk){
      res.write(chunk);
    });
    res.end();
  } else {
    if (req.headers['if-none-match']) {
      res.writeHead(304, {});
      res.end();
    } else if (oraSock === false) {
      res.writeHead(500, {});
      res.end('too long after the page owning the css send the request, the css is removed from server after timeout');
      return;
    }
    res.writeHead(400, {'x-no-css' : 'no-css-item'});
    res.end('please donnot refresh the css manually!');
  }
};