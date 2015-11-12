/**
 * Created by cuccpkfs on 14-12-15.
 */
"use strict";

var EE = require('events').EventEmitter
  , parse = require('./../RSParser.js').rsParse
  , pathJoin = require('path').join
  , mimeType = /text\/resultsets/
  , mimeLen = mimeType.length
  , urlParse = require('url').parse
  , debug = require('debug')('noradle:ResultSets')
  , LF1 = /\x1E\x0A/g
  , LF2 = "\x1E\\n"
  ;

try {
  var cons = require('consolidate');
} catch (e) {
  debug('\n[WARN] Can not find/load "consolidate" module, so apply data to template is not supported !');
  debug('You can run "npm install consolidate" to install consolidate nodeJS module.\n');
}

module.exports = function(cfg){
  var templateMap = cfg.template_map || {};
  return function ResultSetsFilter(oraRes, res, req, rb, next){
    var contentType = res.getHeader('Content-Type');
    if (!contentType) return oraRes;
    if (!res.getHeader('Content-Type').match(mimeType)) return oraRes;

    var chunks = []
      , count = 0
      , ee = new EE()
      , callback = res.getHeader('_callback')
      , template = res.getHeader('_template') || ''
      , engine = res.getHeader('_engine')
      , useRaw
      ;

    if (template && !engine) {
      if (template.split('.').length == 1) {
        engine = cfg.template_engine || '';
      } else {
        var suffix = template.split('.').pop()
        engine = templateMap[suffix] || suffix
      }
    }

    if (template) {
      useRaw = false;
    } else if ((req.headers['accept'] || '').match(mimeType) || res.getHeader('_useraw')) {
      useRaw = true;
      if (!callback) return oraRes;
    } else {
      useRaw = false;
    }

    if (true) {
      callback && res.removeHeader('_callback');
      template && res.removeHeader('_template');
      engine && res.removeHeader('_engine');
      useRaw && res.removeHeader('_userRaw');
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
        try {
          var rss = parse(buf.toString('utf8'));
        } catch (e) {
          var errString = new Buffer(e.toString());
          res.removeHeader('Transfer-Encoding');
          res.setHeader('Content-Type', 'text/plain');
          res.setHeader('Content-Length', errString.length.toString());
          res.statusCode = 500;
          ee.emit('data', errString);
          ee.emit('end');
          return;
        }
        if (cons && template && engine) {
          try {
            if (!cons[engine]) {
              throw new Error('no ' + engine + ' installed with consolidate');
            }
            cons[engine](pathJoin(cfg.template_dir, template), rss)
              .then(function(text){
                var bText = new Buffer(text);
                res.setHeader('Content-Type', 'text/html; charset=utf-8');
                res.setHeader('Content-Length', bText.length.toString());
                ee.emit('data', bText);
                ee.emit('end');
              })
              .catch(function(err){
                next(err);
              });
          } catch (e) {
            next(e);
          }
          return;
        }
        if (rss.$OBJECTS) {
          rss = rss.$OBJECTS.rows;
        } else if (rss.$OBJECT) {
          rss = rss.$OBJECT.rows.shift();
        }
        var rJson = JSON.stringify(rss)
          , bJson = new Buffer(rJson)
          ;
        res.removeHeader('Transfer-Encoding');
        if (!callback) {
          res.setHeader('Content-Type', 'application/json');
          res.setHeader('Content-Length', (bJson.length).toString());
          ee.emit('data', bJson);
        } else {
          res.setHeader('Content-Type', 'application/javascript');
          res.setHeader('Content-Length', (bJson.length + callback.length + 2).toString());
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


