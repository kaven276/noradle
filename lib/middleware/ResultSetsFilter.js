/**
 * Created by cuccpkfs on 14-12-15.
 */

var EE = require('events').EventEmitter
  , parse = require('./../RSParser.js').rsParse
  , mimeType = /text\/resultsets/
  , mimeLen = mimeType.length
  , urlParse = require('url').parse
  , debug = require('debug')('noradle:ResultSets')
  , LF1 = /\x1E\x0A/g
  , LF2 = "\x1E\\n"
  ;

module.exports = function(cfg){
  return function ResultSetsFilter(oraRes, res, req, rb){
    var contentType = res.getHeader('Content-Type');
    if (!contentType) return oraRes;
    if (!res.getHeader('Content-Type').match(mimeType)) return oraRes;

    var chunks = []
      , count = 0
      , ee = new EE()
      , callback = res.getHeader('_callback')
      , useRaw
      ;
    if (callback) {
      useRaw = (res.getHeader('_useraw')) ? true : false;
    } else {
      useRaw = ((req.headers['accept'] || '').match(mimeType)) ? true : false;
      if (useRaw) return oraRes;
    }

    oraRes.on('data', function(data){
      if (!data) return true;
      chunks.push(data);
      count += data.length;
    });

    oraRes.on('end', function(){
      var buf = new Buffer(count)
        , offset = 0
        ;
      chunks.forEach(function(chunk){
        chunk.copy(buf, offset);
        offset += chunk.length;
        output(buf);
      });
    });

    function output(buf){
      if (useRaw == true) {
        // must be JSONP request
        var rss = new Buffer([callback, '("', buf.toString('utf8').replace(LF1, LF2), '");'].join(''));
        res.setHeader('Content-Type', 'application/javascript');
        res.setHeader('Content-Length', rss.length.toString());
        ee.emit('data', rss);
        ee.emit('end');
      } else {
        var rss = parse(buf.toString('utf8'))
          ;
        if (rss.$OBJECTS) {
          rss = rss.$OBJECTS.rows;
        } else if (rss.$OBJECT) {
          rss = rss.$OBJECT.rows.shift();
        }
        var rJson = JSON.stringify(rss)
          , bJson = new Buffer(rJson)
          ;
        res.removeHeader('Transfer-Encoding');
        res.removeHeader('_convert');
        res.setHeader('x-pw-convert', 'text/resultsets');
        if (!callback) {
          res.setHeader('Content-Type', 'application/json');
          res.setHeader('Content-Length', (bJson.length).toString())
          ee.emit('data', bJson);
        } else {
          res.setHeader('Content-Type', 'application/javascript');
          res.setHeader('Content-Length', (bJson.length + callback.length + 2).toString())
          ee.emit('data', new Buffer(callback + '('));
          ee.emit('data', bJson);
          ee.emit('data', new Buffer(');'));
        }
        ee.emit('end');
      }
    }

    return ee;
  };
};


