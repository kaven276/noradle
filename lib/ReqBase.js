"use strict";
var urlParse = require('url').parse
  , progPattern = /^(\w+_[a-z])(\.(\w+))?$/
  , filePattern = /\./
  , debug = require('debug')('noradle:ReqBase')
  , _ = require('underscore')
  ;

function qsort(str){
  return str.split(/ *, */).map(function(v){
    var nv = v.split(';');
    return {
      n : nv[0],
      q : parseFloat((nv[1] || 'q=1').split('=')[1])
    }
  }).sort(function(a, b){
    return b.q - a.q;
  }).map(function(v){
    return v.n;
  });
}

// parsing request line
// fixed part from request line, use to find the plsql stored procedure called
function ReqBase(r, cfg){
  var me = this
    , urlStr = r.originalUrl || r.url
    , url = urlParse(urlStr, false)
    , h = r.headers
    , i, j, len
    ;

  me.done = true;

  // request line info
  (function(me, r){
    me.u$method = r.method;
    me.u$proto = r.connection.encrypted ? 'https' : 'http';
    me.u$url = urlStr;
    me.u$pathname = url.pathname;
    me.u$qstr = url.query;
  })(me, r);

  // host info for multi host, multi port web server
  (function(me, host){
    if (host) {
      host = host.split(":");
      me.u$hostname = host[0];
      me.u$port = host[1] || '80';
    } else {
      // http 1.0
      var addr = r.socket.address();
      me.u$hostname = addr.address;
      me.u$port = addr.port;
    }
  })(me, h.host);

  if (cfg.use_negotiation) {
    if (h['accept']) {
      me['h$$accept'] = qsort(h['accept']);
    }
    if (h['accept-encoding']) {
      me['h$$accept-encoding'] = qsort(h['accept-encoding']);
    }
    if (h['accept-language']) {
      me['h$$accept-language'] = qsort(h['accept-language']);
    }
    if (h['accept-charset']) {
      me['h$$accept-charset'] = qsort(h['accept-charset']);
    }
  }

  if (cfg.url_pattern) {
    var sects = url.pathname.split('/')
      , last = sects[sects.length - 1]
      ;
    if (cfg.omit_file_url && last.match(filePattern) && !last.match(progPattern)) {
      me.x$bypass = ("last section of url(@) show it's a static file".replace('@', urlStr));
      return;
    }
    var model = cfg.url_pattern.split('/');
    for (i = 1, j = 1, len = model.length; i < len; i++) {
      var name = model[i]
        , value = sects[j]
        ;
      if (!value) break;
      if (value.match(progPattern)) {
        if (name === 'x$prog') {
          // 1.normal flat url
          me['x$prog'] = value;
          me.u$dir = sects.slice(0, j).join('/') + '/';
          me.u$spath = sects.slice(j + 1).join('/');
          break;
        } else {
          // 2.omit some part
          me[name] = '';
        }
      } else {
        if (name === 'x$prog') {
          // 3.restful url
          me.u$dir = sects.slice(0, j).join('/') + '/';
          var pack = '';
          for (i = j; i < len; i += 2) {
            pack += sects[i] + '_';
            (i + 1 < len) && (me['i$' + sects[i]] = sects[i + 1]);
          }
          pack = pack + 'h';
          if (pack.length > 30) {
            pack = cfg.package_map[pack];
          }
          me.x$prog = pack + '.action';
          me.z$array = ((len - j) % 2 ? 'true' : 'false');
          break;
        } else {
          // 4.fill name-value pair
          if (name.substr(1, 1) === '$') {
            me[name] = value;
          }
          j++;
        }
      }
    }

    if (!me.x$dbu) {
      // try specify a x$dbu
      me.x$dbu = cfg.x$dbu || '';
    }
    if (!me.x$prog) {
      if (urlStr.substr(-1) !== '/') {
        me.u$location = urlStr + '/';
        return;
      }
      if (i < len - 1) {
        // break before all model sects are scanned, parent not exists
        if (cfg['x$prog' + i]) {
          me.x$prog = cfg['x$prog' + i];
        } else {
          me.u$location = cfg.u$location || ('/' + cfg.x$dbu + '/');
          return;
        }
      } else {
        // parent exists, no prog only
        me.x$prog = cfg.x$prog || 'default_b.d';
      }
      me.u$dir = sects.join('/');
    }

    if (!me.s$) {
      me.s$ = me.x$dbu;
    }
  }

  if (cfg.a$) {
    //{ address: '127.0.0.1', family: 'IPv4', port: 1080 }
    var sa = r.connection.address();
    me.a$sfami = sa.family;
    me.a$saddr = sa.address;
    me.a$sport = sa.port.toString();
    me.a$caddr = r.connection.remoteAddress;
    me.a$cport = r.connection.remotePort.toString();
  }

  if (cfg.use_proxy) {
    if (h['x-forwarded-for']) {
      me['h$$x-forwarded-for'] = h['x-forwarded-for'].split(/ *, */);
    }
    if (h['x-forwarded-port']) {
      me['h$$x-forwarded-port'] = h['x-forwarded-port'].split(/ *, */);
    }
    if (h['x-forwarded-proto']) {
      me['h$$x-forwarded-proto'] = h['x-forwarded-proto'].split(/ *, */);
    }
  }

  me.c$MSID = undefined;
  me.c$BSID = undefined;
  me.h$ = cfg.h$;
  me.c$ = cfg.c$;
  me.x$before = cfg.x$before;
  me.x$after = cfg.x$after;
  me.l$ = cfg.l$;
  me.t$ = cfg.t$;
  me.f$feedback = cfg.f$feedback;

  me.done = true;
}

module.exports = ReqBase;