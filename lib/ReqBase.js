var urlParse = require('url').parse
  , cfg = require('./cfg.js')
  , CRLF = '\r\n'
  ;

// parsing request line
// fixed part from request line, use to find the plsql stored procedure called
function ReqBase(r){
  var me = this
    ;

  // request line info
  (function(me, r){
    var method = r.method
      , h = r.headers
      , host = h.host
      ;
    me.u$method = r.method;
    me.u$proto = r.headers['x-forwarded-proto'] || (!r.connection.encrypted) ? 'http' : 'https';
    me.u$url = r.url;
  })(me, r);

  // host info for multi host, multi port web server
  (function(me, host){
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
  })(me, r.headers.host);

  (function(){
    var url = urlParse(r.url, false)
      , path_sects = url.pathname.substr(1).split('/')
      ;
    me.u$base = cfg.plsql_mount_point.replace(/(^\/|\/$)/, '') || '';
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
  })();

  me.a$caddr = r.headers['x-forwarded-for'] || r.connection.remoteAddress;
  me.a$caddr = me.a$caddr.split(',')[0].trim();
  me.a$cport = r.headers['x-forwarded-port'] || r.connection.remotePort.toString();
  me.a$cport = me.a$cport.split(',')[0].trim();

  me.i$bsid = null;
  me.i$msid = null;
  me.a$uaHash = null;
}

module.exports = ReqBase;