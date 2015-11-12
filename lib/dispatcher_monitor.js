#!/usr/bin/env node

/**
 * Created by cuccpkfs on 15-6-15.
 */

"use strict";

var dnode = require('dnode')
  , net = require('net')
  , http = require('http')
  , urlParse = require('url').parse
  , C = require('./constant.js')
  , dispatcher
  , debug = require('debug')('noradle:monitor')
  ;


function connectToDispatcher(addr){
  debug('addr', addr);
  if (typeof addr === 'number') {
    addr = addr.toString();
  }
  function connect(){
    var d = dnode();
    d.on('remote', function(remote){
      debug('remote got');
      dispatcher = remote;
    });
    var c = new net.Socket({allowHalfOpen : true});
    c.connect.apply(c, addr.split(':'));
    c.on('connect', function onConnectionToDispatcher(){
      c.on('readable', function skipMagicNumber(){
        var bytes4 = c.read(4);
        if (!bytes4) return;
        if (bytes4.readInt32BE(0) !== C.DISPATCHER) {
          console.error('connected to none noradle dispatcher');
          c.end();
          return;
        }
        bytes4.writeInt32BE(C.MONITOR, 0);
        c.write(bytes4);
        c.removeListener('readable', skipMagicNumber);
        c.pipe(d).pipe(c);
      });
      c.on('end', function(){
        debug('connection end');
        c.end();
      });
    });

    c.on('error', function(){
      debug('socket error found');
    });

    c.on('close', function(){
      debug('connection close, retry connect');
      setTimeout(connect, 1000);
    });
  }

  connect();
}

var monitor = http.createServer(function(req, res){
  var url = urlParse(req.url)
    , methodName = url.pathname.substr(1)
    , remoteMethod = dispatcher[methodName]
    ;

  if (remoteMethod) {
    remoteMethod(function(data){
      res.writeHead(200, {
        'content-type' : 'application/json'
      });
      res.end(JSON.stringify(data, null, 2));
    });
  } else {
    res.writeHead(404);
    res.end();
  }
});

exports.start_by_env = function(){
  var args = process.argv;
  connectToDispatcher(args[2] || process.env.dispatcher_addr || 1522);
  monitor.listen(args[3] || process.env.http_listen_addr || 1520);
};

if (process.argv[1].match(/.*\/noradle-monitor$/) || process.argv[1] === __filename) {
  exports.start_by_env();
}