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

  me.proto = r.headers['x-forwarded-proto'] || (!r.connection.encrypted) ? 'http' : 'https';
  if (host) {
    host = host.split(":");
    me.host = host[0];
    me.port = parseInt(host[1] || '80');
    var host_sects = me.host.split('.');
    if (me.host.match(/^(\d+\.)+\d+$/)) {
      me.hostp = '';
    } else if (host_sects.length <= cfg.host_base_parts) {
      me.hostp = '';
    } else if (host_sects.length > cfg.host_base_parts + 1) {
      me.hostp = 'error';
    } else {
      me.hostp = host_sects[0];
    }
  } else {
    // http 1.0
    var addr = r.socket.address();
    me.host = addr.address;
    me.port = addr.port;
    me.hostp = '';
  }
  me.method = method;
  var path_sects = url.pathname.split('/');
  me.base = cfg.plsql_mount_point.replace(/(^\/|\/$)/, '') || '';
  path_sects.shift();
  me.dad = path_sects.shift();
  me.prog = path_sects.shift() || 'default_b.d';
  try {
    var parts = me.prog.split('.');
  } catch (e) {
    console.warn('me.prog=' || me.prog);
  }
  if (parts.length === 1) {
    me.pack = '';
    me.proc = r.prog;
  } else {
    me.pack = parts[0];
    me.proc = parts[1];
  }
  me.path = path_sects.join('/') || '';
  me.search = url.search ? url.search.substr(1) : '';

  me.url = r.url;
  me.caddr = r.headers['x-forwarded-for'] || r.connection.remoteAddress;
  me.cport = r.headers['x-forwarded-port'] || r.connection.remotePort;
  me.bsid = null;
  me.msid = null;
}
ReqBase.prototype.setSid = function(bsid, msid, uaHash){
  this.bsid = bsid;
  this.msid = msid;
  this.uaHash = uaHash;
};
ReqBase.prototype.toOraLines = function(){
  var a = this;
  return [ a.method, a.url, a.proto, a.host, a.hostp, a.port, a.base, a.dad, a.prog, a.pack, a.proc, a.path, a.search, a.caddr, a.cport, a.bsid, a.msid, a.uaHash].join(CRLF);
};

module.exports = ReqBase;