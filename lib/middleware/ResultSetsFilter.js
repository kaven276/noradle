/**
 * Created by cuccpkfs on 14-12-15.
 */

var EE = require('events').EventEmitter
  , parse = require('./../RSParser.js').rsParse
  , mimeType = 'text/resultsets;'
  , mimeLen = mimeType.length
  , urlParse = require('url').parse
  ;

module.exports = function(cfg){
  return function ResultSetsFilter(oraRes, res, req, rb){
    var _convert = res.getHeader('_convert');
    if (!_convert) return oraRes;
    if (_convert.match(/^JSONP?$/) && (res.getHeader('Content-Type') || '').substr(0, mimeLen) === mimeType) ; else {
      return oraRes;
    }
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
        ;
      res.removeHeader('Transfer-Encoding');
      res.removeHeader('_convert');
      res.setHeader('x-pw-convert', 'text/resultsets');
      res.setHeader('Content-Type', 'application/json');
      if (_convert == 'JSON') {
        res.setHeader('Content-Length', (bJson.length).toString())
        ee.emit('data', bJson);
      } else if (_convert == 'JSONP') {
        var cb = res.getHeader('_callback') || urlParse(req.url, true).query.callback || 'callback';
        res.setHeader('Content-Length', (bJson.length + cb.length + 2).toString())
        ee.emit('data', new Buffer(cb + '('));
        ee.emit('data', bJson);
        ee.emit('data', new Buffer(');'));
      }
      ee.emit('end');
    });
    return ee;
  };
};


