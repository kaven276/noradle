/**
 * Created by cuccpkfs on 15-6-3.
 * only no error write will automatically do redirect url
 * note: error response means rollback, will not cause repeated write
 */
"use strict";

var curFeedbackSeq = 0
  , fbBuffer = {}
  , debug = require('debug')('noradle:Feedback')
  ;

exports.filter = function(cfg){
  return function Feedback(oraRes, res, req, headers){
    if ((res.getHeader('x-pw-feedback') || 'N') != 'Y') {
      return false;
    }
    if (req.headers['x-requested-with']) {
      return false;
    }
    if (res.getHeader('Content-Length') === '0') {
      var referer = req.headers['referer'];
      if (referer) {
        res.removeHeader('Content-Type');
        res.setHeader('Location', referer);
        res.statusCode = 303;
        res.end();
      } else {
        res.setHeader('Content-Type', 'text/html');
        res.removeHeader('Content-Length');
        res.end('<script>history.back();</script>');
      }
      debug('call _c return back!');
      return true;
    } else if (res.getHeader('Content-Type').match(/^text\/html;/)) {
      // may streamed or not
      store(oraRes, res, headers, function onEnd(){
        res.statusCode = 303;
        res.end();
      });
      return true;
    } else {
      return false;
    }
  };
};

function FBItem(status, headers){
  this.status = status;
  this.headers = headers;
  this.chunks = [];
}

function store(oraRes, res, headers, cb){
  var fbId = ++curFeedbackSeq
    , count = 0
    ;
  debug('store feedback(%d)', fbId);

  headers['ETag'] = '"' + fbId + '"';
  headers['Cache-Control'] = 'max-age=600';
  var fbItem = fbBuffer[fbId] = new FBItem(200, headers);

  oraRes.on('data', function(data){
    fbItem.chunks.push(data);
    count += data.length;
  });

  oraRes.on('end', function(){
    debug('stored feedback(%d) length=%d', fbId, count);
    headers['Content-Length'] = count;
    res.removeHeader('Transfer-Encoding');
    res.removeHeader('Content-Type');
    res.setHeader('Content-Length', '0');
    res.setHeader('Location', 'feedback_b?id=' + fbId);
    res.setHeader('Cache-Control', 'no-cache');
    cb();
  });
};

exports.use = function(res, req, fbId){
  debug('use feedback(%d)', fbId);
  var fbItem = fbBuffer[fbId];
  if (fbItem) {
    delete fbBuffer[fbId];
    res.writeHead(fbItem.status, fbItem.headers);
    fbItem.chunks.forEach(function(chunk){
      res.write(chunk);
    });
    res.end();
  } else {
    if (req.headers['if-none-match']) {
      res.writeHead(304, {});
      res.end();
    } else if (!fbItem) {
      res.writeHead(500, {});
      res.end('too long after the page redirecting to this feedback page send the request, the feedback is removed from server after timeout');
    } else {
      res.writeHead(400, {});
      res.end('please donnot refresh the feedback page manually!');
    }
  }
};