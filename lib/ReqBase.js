var urlParse = require('url').parse
  , cfg = require('./cfg.js')
  , CRLF = '\r\n'
  ;

// parsing request line
// fixed part from request line, use to find the plsql stored procedure called
function ReqBase(r){
  var method = r.method
    , h = r.headers
    , host = h.host
    , url = urlParse(r.url, false)
    , me = this
    ;

  me.u$proto = r.headers['x-forwarded-proto'] || (!r.connection.encrypted) ? 'http' : 'https';
  if (host) {
    host = host.split(":");
    me.u$host = host[0];
    me.u$port = parseInt(host[1] || '80');
    var host_sects = me.u$host.split('.');
    if (me.u$host.match(/^(\d+\.)+\d+$/)) {
      me.u$hostp = '';
    } else if (host_sects.length <= cfg.host_base_parts) {
      me.u$hostp = '';
    } else if (host_sects.length > cfg.host_base_parts + 1) {
      me.u$hostp = 'error';
    } else {
      me.u$hostp = host_sects[0];
    }
  } else {
    // http 1.0
    var addr = r.socket.address();
    me.u$host = addr.address;
    me.u$port = addr.port;
    me.u$hostp = '';
  }
  me.u$method = method;
  var path_sects = url.pathname.split('/');
  me.u$base = cfg.plsql_mount_point.replace(/(^\/|\/$)/, '') || '';
  path_sects.shift();
  me.u$dad = path_sects.shift();
  // me.x$dbu = me.u$dad;
  me.i$gid = '';
  me.x$prog = path_sects.shift() || 'default_b.d';
  try {
    var parts = me.x$prog.split('.');
  } catch (e) {
    console.warn('me.x$prog=' || me.x$prog);
  }
  if (parts.length === 1) {
    me.x$pack = '';
    me.x$proc = parts[0];
  } else {
    me.x$pack = parts[0];
    me.x$proc = parts[1];
  }
  me.u$path = path_sects.join('/') || '';
  me.u$qstr = url.search ? url.search.substr(1) : '';

  me.u$url = r.url;
  me.a$caddr = r.headers['x-forwarded-for'] || r.connection.remoteAddress;
  me.a$caddr = me.a$caddr.split(',')[0].trim();
  me.a$cport = r.headers['x-forwarded-port'] || r.connection.remotePort.toString();
  me.a$cport = me.a$cport.split(',')[0].trim();
  me.i$bsid = null;
  me.i$msid = null;
  me.a$uaHash = null;
}
ReqBase.prototype.setSid = function(bsid, msid, uaHash){
  this.i$bsid = bsid;
  this.i$msid = msid;
  this.a$uaHash = uaHash;
};

module.exports = ReqBase;