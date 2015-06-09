/**
 * Created by cuccpkfs on 15-5-12.
 */

var addMap = require('./util/util.js').addMap
  , util = require("util")
  , events = require("events")
  , reqCnt = 0
  , debug = require('debug')('noradle:steps')
  , writeFrame = require('./util/frame.js').writeFrame
  , split2nvs = require('./util/util.js').split2nvs
  , C = require('./constant.js')
  , getNow = require('./util/util.js').getNow
  ;

function Request(slotID, stream, env){
  events.EventEmitter.call(this);
  this._buf = ['', ''];
  this.headerSent = false;
  this.quitting = false;
  this.follows = [];
  this.slotID = slotID;
  this.stream = stream;
  this.env = env;
  this.reqCnt = ++reqCnt;
  this.stime = getNow();
}
util.inherits(Request, events.EventEmitter);

Request.prototype.init = function(protocol, hprof){
  this._buf[0] = protocol || 'BIOS';
  this._buf[1] = hprof || '';
  return this;
};

Request.prototype.addHeaders = function(obj, prefix){
  addMap(this._buf, obj, prefix);
  return this;
};

Request.prototype.addHeader = function(name, value){
  this._buf.push(name, value);
  return this;
};

Request.prototype._sendHeaders = function(){
  if (this.headerSent) return;
  writeFrame(this.stream, this.slotID, C.HEAD_FRAME, 0, new Buffer(this._buf.join('\r\n') + '\r\n\r\n\r\n'));
  this.headerSent = true;
  return this;
};

Request.prototype.write = function(chunk){
  this._sendHeaders();
  if (!chunk) return;
  writeFrame(this.stream, this.slotID, C.BODY_FRAME, 0, chunk);
  debug(this.reqCnt, this.env, 'header sent');
  return this;
};

Request.prototype.end = function(cb){
  var req = this, res, status, headers, session;
  this._sendHeaders();
  // mark zero-length frame for end of request
  writeFrame(this.stream, this.slotID, C.END_FRAME, 0, null);
  this.on('frame', function(head, slotID, type, flag, len, body){
    switch (type) {
      case C.HEAD_FRAME:
        var lines = body.toString('utf8').split('\r\n')
        debug('response head', lines);
        lines.pop();
        status = parseInt(lines.shift());
        headers = split2nvs(lines);
        res = new Response(status, headers);
        cb(res);
        break;
      case C.SESSION_FRAME:
        debug('response session, %s', body.toString('utf8'));
        var lines = body.toString('utf8').split('\r\n');
        lines.pop();
        session = split2nvs(lines);
        res.emit('session', session);
        break;
      case C.END_FRAME:
        debug('all response received');
        res.emit('end', []);
        return;
      case C.ERROR_FRAME:
        debug('error received');
        res.emit('error', body);
        return;
      default:
        // C.BODY_FRAME, C.CSS_FRAME
        debug('response body, %s', body.toString('utf8'));
        res.emit('data', body, type);
    }
  });
};

function Response(status, headers){
  events.EventEmitter.call(this);
  this.status = status;
  this.headers = headers;
}
util.inherits(Response, events.EventEmitter);

module.exports = Request;
