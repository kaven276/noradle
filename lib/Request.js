var addMap = require('./util.js').addMap
  , util = require("util")
  , events = require("events")
  , reqCnt = 0
  , logger = require('./logger.js')
  ;

function Request(oraSock, env){
  events.EventEmitter.call(this);
  this.oraSock = oraSock;
  this._buf = ['', ''];
  this.quitting = false;
  this.follows = [];
  this.env = env;
  this.reqCnt = ++reqCnt;
  oraSock.on('socket_released', function abort(){
    logger.steps('oraSock end/error, aborted!');
    req.emit('abort');
    // todo: signal client
  });
}
util.inherits(Request, events.EventEmitter);

Request.prototype.init = function(protocol, hprof){
  this._buf[0] = protocol;
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
  try {
    this.oraSock.write(this._buf.join('\r\n') + '\r\n\r\n\r\n');
  } catch (e) {
    console.error('sendReqHead exception.');
  }
  return this;
};

Request.prototype.end = function(cb){
  var req = this, res, c = this.oraSock, hasRead = false, hLen, bLen, cLen, bom, cSeq = 0;
  req._sendHeaders();
  logger.steps(req.reqCnt, req.env, 'header sent');
  c.on('readable', read);

  function resFin(){
    logger.steps(req.reqCnt, req.env, 'all got');
    res.emit('end');
    if (req.follows.length === 0) {
      c.removeListener('readable', read);
      c.removeAllListeners('socket_released');
      req.emit('fin');
    } else {
      logger.steps(req.reqCnt, req.env, 'has follow', req.follows);
      res = undefined;
      hLen = undefined;
      read();
    }
  }

  function read(){
    if (!hasRead) {
      hasRead = true;
      logger.steps(req.reqCnt, req.env, 'first got');
    }
    var data;

    // 1. expect response header length
    if (!hLen) {
      if (null === (data = c.read(4))) {
        logger.steps(req.reqCnt, req.env, 'null hLen');
        return;
      }
      if ((hLen = data.readInt32BE(0)) < 0) {
        // todo:
        logger.steps(req.reqCnt, req.env, 'quitting signal received');
        req.quitting = true;
        hLen = undefined;
        read();
        return;
      }
      logger.steps(req.reqCnt, req.env, 'hLen got', hLen);
    }

    if (!res) {
      // 2. expect whole response header text
      if (null === (data = c.read(hLen))) {
        return;
      }
      var oraResHead = data.toString('ascii').split('\r\n')
        , status = parseInt(oraResHead.shift().split(' ').shift())
        , header = {}
        ;
      oraResHead.pop();
      oraResHead.forEach(function(nv){
        nv = nv.split(": ");
        // todo: multi occurrence headers not supported by now
        if (nv[0] === 'Set-Cookie') {
          if (header[nv[0]]) header['Set-Cookie'].push(nv[1]);
          else header['Set-Cookie'] = [nv[1]];
        } else {
          header[nv[0]] = nv[1];
        }
      });
      logger.steps(req.reqCnt, req.env, 'header got');

      // 3. fix headers, bLen
      bLen = parseInt(header['Content-Length']);
      bom = header['x-pw-bom-hex'];
      if (bom && bLen >= 0) {
        bLen += bom.length / 2;
        header['Content-Length'] = bLen.toString();
      }

      // 4. after header got, do callback with res
      res = new Response(status, header);
      req.emit('response', res);
      cb(res);

      // 5. empty body? just do fin work
      if (bLen === 0) {
        resFin();
        return;
      }
    }

    if (bLen) {
      // 7. expect whole response body
      if (null === (data = c.read(bLen))) {
        return;
      }
      res.emit('data', data);
      resFin();
      return;
    } else {
      // transfer-encoding = chunked
      if (bom) {
        if (null === (data = c.read(bom.length / 2))) {
          return;
        }
        res.emit('data', data);
        bom = undefined;
      }
      while (true) {
        if (!cLen) {
          // 4. expect chunk length value
          if (null === (data = c.read(4))) {
            return;
          }
          if (0 === (cLen = data.readInt32BE(0))) {
            logger.steps('chunked transfer end');
            resFin();
            return;
          }
        }
        // 5. expect whole chunk body
        if (null === (data = c.read(cLen))) {
          return;
        }
        logger.steps('chunk', ++cSeq, data.toString('utf8').substr(0, 20));
        res.emit('data', data);
        cLen = 0;
      }
    }
  }
};

function Response(status, headers){
  events.EventEmitter.call(this);
  this.status = status;
  this.headers = headers;
}
util.inherits(Response, events.EventEmitter);

module.exports = Request;
