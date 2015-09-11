/**
 * Created by cuccpkfs on 14-12-15.
 */

var EE = require('events').EventEmitter
  , parse = require('./../RSParser.js').rsParse
  , mimeType = /text\/resultsets/
  , mimeLen = mimeType.length
  , urlParse = require('url').parse
  , debug = require('debug')('noradle:ResultSets')
  ;

module.exports = function(cfg){
  return function ResultSetsFilter(oraRes, res, req, rb){
    if (!res.getHeader('Content-Type')) return oraRes;
    if (!res.getHeader('Content-Type').match(mimeType)) return oraRes;
    if ((req.headers['accept'] || '').match(mimeType)) return oraRes;
    var chunks = []
      , count = 0
      , ee = new EE()
      ;
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
      });
      var rss = parse(buf.toString('utf8'))
        , rJson = JSON.stringify(rss)
        , bJson = new Buffer(rJson)
        , callback = res.getHeader('_callback')
        ;
      res.removeHeader('Transfer-Encoding');
      res.removeHeader('_convert');
      res.setHeader('x-pw-convert', 'text/resultsets');
      res.setHeader('Content-Type', 'application/json');
      if (!callback) {
        res.setHeader('Content-Length', (bJson.length).toString())
        ee.emit('data', bJson);
      } else {
        res.setHeader('Content-Length', (bJson.length + callback.length + 2).toString())
        ee.emit('data', new Buffer(callback + '('));
        ee.emit('data', bJson);
        ee.emit('data', new Buffer(');'));
      }
      ee.emit('end');
    });
    return ee;
  };
};


