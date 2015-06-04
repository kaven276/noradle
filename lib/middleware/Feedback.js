/**
 * Created by cuccpkfs on 15-6-3.
 */

var curFeedbackSeq = 0
  , fbBuffer = {}
  , debug = require('debug')('noradle:Feedback')
  ;

function FBItem(status, headers){
  this.status = status;
  this.headers = headers;
  this.chunks = [];
}

exports.store = function Feedback(oraRes, ohdr, cb){
  var fbId = ++curFeedbackSeq
    , headers = oraRes.headers
    , count = 0
    ;
  debug('store feedback(%d)', fbId);

  headers['ETag'] = '"' + fbId + '"';
  headers['Cache-Control'] = 'max-age=600';
  fbItem = fbBuffer[fbId] = new FBItem(oraRes.status, headers);

  oraRes.on('data', function(data){
    fbItem.chunks.push(data);
    count += data.length;
  });

  oraRes.on('end', function(){
    debug('stored feedback(%d) length=%d', fbId, count);
    headers['Content-Length'] = count;
    delete ohdr['Transfer-Encoding'];
    delete ohdr['Content-Type'];
    ohdr['Content-Length'] = '0';
    ohdr['Location'] = 'feedback_b?id=' + fbId;
    ohdr['Cache-Control'] = 'no-cache';
    cb();
  });
};

exports.use = function(res, fbId){
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