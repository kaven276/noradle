/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 15-10-8
 * Time: 下午8:42
 *
 * any convert that convert response body text to another text, like markdown to html
 * cfg.converters = { name: converter_function, ... } user supply its converter, noradle don't
 */
"use strict";

var EE = require('events').EventEmitter
  ;

module.exports = function(cfg){
  var converters = (cfg.converters || {});
  return function MarkdownFilter(oraRes, res){
    var converterName = res.getHeader('_convert');
    if (!converterName) {
      return oraRes;
    }
    var converter = converters[converterName];
    if (!converter || typeof converter !== 'function') {
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
      output(buf);
    });
    function output(buf){
      var html = new Buffer(converter(buf.toString()));
      res.removeHeader('Transfer-Encoding');
      res.removeHeader('_convert');
      res.setHeader('Content-Length', html.length.toString());
      res.setHeader('Content-Type', 'text/html; charset=UTF-8');
      ee.emit('data', html);
      ee.emit('end');
    }

    return ee;
  };
};