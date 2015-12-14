/**
 * Created by cuccpkfs on 15-5-12.
 */
"use strict";

var util = require("util")
  , events = require("events")
  , reqCnt = 0
  , debug = require('debug')('noradle:steps')
  , writeFrame = require('noradle-protocol').frame.writeFrame
  , C = require('noradle-protocol').constant
  , getNow = require('./util/util.js').getNow
  ;

function split2nvs(lines){
  var nvs = {}, nv, setCookies = false;
  for (var i = 0, len = lines.length; i < len; i++) {
    if (setCookies) {
      setCookies.push(lines[i]);
    } else if (lines[i] === 'Set-Cookies: ') {
      nvs['Set-Cookie'] = setCookies = [];
    } else {
      nv = lines[i].split(': ');
      nvs[nv[0]] = nv[1];
    }
  }
  return nvs;
};

function Request(slotID, stream, env){
  events.EventEmitter.call(this);
  this._buf = ['', ''];
  this.headerSent = false;
  this.quitting = false;
  this.error = false;
  this.follows = [];
  this.slotID = slotID;
  this.stream = stream;
  this.env = env;
  this.reqCnt = ++reqCnt;
  //this.stime = getNow();
}
util.inherits(Request, events.EventEmitter);

Request.prototype.init = function(protocol, hprof){
  this._buf[0] = protocol || 'BIOS';
  this._buf[1] = hprof || '';
  return this;
};

Request.prototype.addHeaders = function(obj, pre){
  var buf = this._buf
    , core = arguments.length >= 2
    ;
  pre = pre || '';
  for (var n in obj) {
    if (obj.hasOwnProperty(n) && n.substr(0, 2) !== '__' && (core || n.charAt(1) !== '$')) {
      var v = obj[n];
      if (v instanceof Array) {
        buf.push('*' + pre + n, v.length);
        Array.prototype.push.apply(buf, v);
      } else if (v !== undefined) {
        buf.push(pre + n, v);
      }
    }
  }
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
  if (!chunk) return this;
  writeFrame(this.stream, this.slotID, C.BODY_FRAME, 0, chunk);
  debug(this.reqCnt, this.env, 'header sent');
  return this;
};

/**
 * send fin frame for the request
 * @param cb onResponse(status, headers) when response header is received
 */
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
        if (!req.error) res.emit('end', []);
        return;
      case C.ERROR_FRAME:
        debug('error received', body.toString());
        req.error = true;
        req.emit('error', body);
        return;
      default:
        // C.BODY_FRAME, C.CSS_FRAME
        debug('response body, %s', body && body.length);
        res.emit('data', body, type);
    }
  });
};

function Response(status, headers, cached){
  events.EventEmitter.call(this);
  this.status = status;
  this.headers = headers;
  this.cached = cached;
}
util.inherits(Response, events.EventEmitter);

exports.Request = Request;
exports.Response = Response;
