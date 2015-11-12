/**
 * Created by cuccpkfs on 14-12-11.
 */
"use strict";

exports.onResponseTimeout = function(res){
  return function(interval){
    var errmsg = 'execute over ' + interval + ' milliseconds and nothing response received!';
    res.writeHead(504, 'Gateway Timeout', {
      'Content-Length' : errmsg.length,
      'Content-Type' : 'text/plain',
      'Retry-After' : '3'
    });
    res.end(errmsg);
  };
};

exports.onSocketReleased = function(res){
  return function(interval){
    var errmsg = 'execute over ' + interval + ' milliseconds and busy socket released!';
    res.writeHead(500, 'Internal Server Error', {
      'Content-Length' : errmsg.length,
      'Content-Type' : 'text/plain',
      'Retry-After' : '3'
    });
    res.end(errmsg);
  };
};

exports.onNoFreeConnection = function(res){
  return function(err){
    // console.log('no database server connection/process available');
    var errmsg = 'waiting for free database connection timeout';
    res.writeHead(503, 'Service Unavailable', {
      'Content-Length' : errmsg.length,
      'Content-Type' : 'text/plain',
      'Retry-After' : '3'
    });
    res.end(errmsg);
  };
};

exports.onGeneralError = function(res){
  return function(err){
    var errmsg = err.toString();
    res.writeHead(400, {
      'Content-Length' : errmsg.length,
      'Content-Type' : 'text/plain'
    });
    res.end(errmsg);
  };
};
