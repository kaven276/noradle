/**
 * Created by cuccpkfs on 15-6-4.
 */
"use strict";

var EE = require('events').EventEmitter
  , cssBuffer = {}
  , debug = require('debug')('noradle:CSS')
  , C = require('noradle-protocol').constant
  , bufStyleOpen = new Buffer('<style>')
  , bufStyleClose = new Buffer('</style>')
  ;

function CSSItem(cssFrame, headers){
  this.cssFrame = cssFrame;
  this.headers = headers;
}

exports.filter = function(cfg){
  return function CSS(oraRes){
    var embedTag = oraRes.headers['x-embed-css']
      , embed = false
      , cssmd5
      , cssFrame
      , later = []
      , ee
      ;
    if (!embedTag) return oraRes;

    oraRes.on('data', function(data, type){
      switch (type) {
        case C.BODY_FRAME:
          if (!embed) {
            ee.emit('data', data, C.BODY_FRAME);
          } else {
            later.push(data);
          }
          break;
        case C.EMBED_FRAME:
          embed = true;
          break;
        case C.HASH_FRAME:
          cssmd5 = data.toString('base64');
          break;
        case C.STYLE_FRAME:
          cssFrame = data;
          break;
      }
    });
    oraRes.on('end', function(){
      if (embedTag === 'link') {
        cssBuffer[cssmd5] = new CSSItem(cssFrame, {
          'ETag' : '"' + cssmd5 + '"',
          'Content-Type' : 'text/css',
          'Content-Length' : cssFrame.length,
          'Cache-Control' : 'max-age=60000'
        });
        ee.emit('data', new Buffer('<link type="text/css" rel="stylesheet" href="css_b/' + cssmd5 + '"/>'), C.BODY_FRAME);
      } else {
        ee.emit('data', bufStyleOpen, C.BODY_FRAME);
        ee.emit('data', cssFrame, C.BODY_FRAME);
        ee.emit('data', bufStyleClose, C.BODY_FRAME);
      }
      for (var i = 0, len = later.length; i < len; i++) {
        ee.emit('data', later[i], C.BODY_FRAME);
      }
      ee.emit('end');
    });
    return ee = new EE();
  };
};

exports.use = function(res, cssmd5){
  debug('use CSS(%s)', cssmd5);
  var cssItem = cssBuffer[cssmd5];
  if (cssItem) {
    delete cssBuffer[cssmd5];
    res.writeHead(200, cssItem.headers);
    res.end(cssItem.cssFrame);
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