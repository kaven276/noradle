var urlParse = require('url').parse
  , cfg = require('./cfg.js')
  ;

var map = {
  'GETs' : 'query',
  'GET' : 'one',
  'POST' : 'post'
};

// parsing request line
// fixed part from request line, use to find the plsql stored procedure called
function ReqBase(r){
  var me = this
    , rurl2 = r.originalUrl || r.url
    , url = urlParse(rurl2, false)
    , h = r.headers
    ;

  me.done = true;

  // request line info
  (function(me, r){
    me.u$method = r.method;
    me.u$proto = r.connection.encrypted ? 'https' : 'http';
    me.u$url = rurl2;
    me.u$pathname = url.pathname;
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
  if (cfg.url_map) {
    (function(){
      var mountPoint = r.originalUrl.replace(r.url, '')
        , base = mountPoint.split('/').length - 1
        , path_sects = urlParse(r.url, false).pathname.split('/')
        ;
      me.x$dbu = path_sects[1];
      me.x$app = path_sects[1];
      me.u$dir = mountPoint + path_sects.slice(0, 2).join('/') + ((path_sects.length > 2) ? '/' : '');
      me.x$prog = path_sects[2] || 'default_b.d';
      if (me.x$prog.match(/_\w(\.|$)/)) {
        me.u$spath = path_sects.slice(3).join('/');
      } else {
        var path = path_sects.slice(2), pack = '', proc;
        for (var i = 0; i < path.length; i += 2) {
          pack += path[i] + '_';
          (i + 1 < path.length) && (me['i$' + path[i]] = path[i + 1]);
        }
        pack = pack + 'h';
        proc = map[r.method + (path.length % 2 ? 's' : '')];
        me.x$prog = pack + '.' + proc;
        me.z$array = (path.length % 2 ? 'true' : 'false');
        console.log(me);
      }
      me.y$before = 'k_filter.before';
      me.y$after = 'k_filter.after';
      me.y$static = cfg.static_url + me.x$dbu + '/';
    })
    ();
  }

  //{ address: '127.0.0.1', family: 'IPv4', port: 1080 }
  var sa = r.connection.address();
  me.a$sfami = sa.family;
  me.a$saddr = sa.address;
  me.a$sport = sa.port.toString();
  me.a$caddr = r.connection.remoteAddress;
  me.a$cport = r.connection.remotePort.toString();

  me.c$MSID = undefined;
  me.c$BSID = undefined;
  me.i$gid = '';
  me.t$timespan = 'Y';
  me.f$feedback = 'Y';

  me.done = true;
}

module.exports = ReqBase;