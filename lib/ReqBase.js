var urlParse = require('url').parse
  , cfg = require('./cfg.js')
  ;

// parsing request line
// fixed part from request line, use to find the plsql stored procedure called
function ReqBase(r){
  var me = this
    , rurl2 = r.original_url || r.url
    , url = urlParse(rurl2, false)
    , h = r.headers
    ;

  // request line info
  (function(me, r){
    me.u$method = r.method;
    me.u$proto = r.connection.encrypted ? 'https' : 'http';
    me.u$url = rurl2;
    me.u$qstr = url.query;
  })(me, r);

  // host info for multi host, multi port web server
  (function(me, host){
    if (me.host) return;
    if (host) {
      host = host.split(":");
      me.u$hostname = host[0];
      me.u$port = host[1] || '80';
      if (me.u$hostname.match(/^(\d+\.)+\d+$/)) {
        // like 8.8.8.8
        me.u$sdns = '';
      } else {
        // like www.noradle.com
        var host_sects = me.u$hostname.split('.');
        me.u$pdns = host_sects.slice(-cfg.host_base_parts).join('.');
        if (host_sects.length <= cfg.host_base_parts) {
          me.u$sdns = '';
        } else if (host_sects.length > cfg.host_base_parts + 1) {
          me.u$sdns = 'error';
        } else {
          me.u$sdns = host_sects[0];
        }
      }
    } else {
      // http 1.0
      var addr = r.socket.address();
      me.u$hostname = addr.address;
      me.u$port = addr.port;
      me.u$sdns = '';
    }
  })(me, h.host);

  // determine db.dbu.prog
  (function(){
    var path_sects = url.pathname.split('/');
    me.x$dbu = path_sects[1];
    me.u$dir = path_sects.slice(0, 2).join('/') + (sects.length > 2) ? '/' : '';
    me.x$prog = path_sects[2] || 'default_b.d';
    me.u$spath = path_sects.slice(3).join('/');
  })();

  me.y$before = 'k_filter.before';
  me.y$after = 'k_filter.after';
  me.y$static = cfg.static_url + me.x$dbu + '/';

  me.a$caddr = r.connection.remoteAddress;
  me.a$cport = r.connection.remotePort.toString();

  me.c$MSID = null;
  me.c$BSID = null;
  me.i$gid = '';
}

module.exports = ReqBase;