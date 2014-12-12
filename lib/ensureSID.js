/**
 * Created by cuccpkfs on 14-12-12.
 */

var guidMgr = require('./guidMgr.js')
  , fmt = require('util').format
  , mGuard = require('./SidGuard.js')
  , onGeneralError = require('./error_pages.js').onGeneralError
  ;

module.exports = function ensureSID(req, res, bakRes, rb, ohdr, cfg){
  var host = req.headers.host
    , port = rb.u$port
    , fstReq = (res.socket._bytesDispatched === 0)
    , cookies = req.cookies
    , msid = cookies['MSID']
    , bsid = cookies['BSID']
    , guard = cookies['GUARD' + port]
    , newGuard
    , ua = req.headers['user-agent'] || ''
  //, uaHash = utl.hash2(ua)
    , setCookies = []
    , writeHead
    ;

  delete cookies['GUARD' + port];
  ohdr['Set-Cookie'] = setCookies;

  if (bsid && cfg.check_session_hijack) {
    try {
      if (newGuard = mGuard.checkUpdate(host, bsid, guard, rb.a$caddr)) {
        writeHead = bakRes.writeHead;
        bakRes.writeHead = function(sts, headers){
          if (typeof newGuard === 'function') {
            newGuard = newGuard();
          }
          ohdr['Set-Cookie'].push(fmt('GUARD%d=%s;Version=1;Path=/', port, newGuard));
          writeHead.call(bakRes, sts, headers);
        };
      }
    } catch (e) {
      (onGeneralError(res))(e);
      return false;
    }
  }

  // UA is not browser and not require session or browser not allow cookie
  if (ua.match(cfg.NoneBrowserPattern) || !fstReq) {
    tellOracle();
    return true;
  }

  function computeHost(){
    if (host) {
      host = host.split(':')[0];
      if (host.slice(-1).match(/\d/) || host.search(/\./) < 0) {
        host = '';
      } else {
        host = host.split('.').slice(-2).join('.')
      }
    }
  }

  function getStripe(){
    var host = req.headers.host;
    if (host) {
      return host;
    } else {
      var addr = req.socket.address();
      return [addr.address, addr.port].join(':');
    }
  }

  function tellOracle(){
    (rb.c$BSID === undefined) && (rb.c$BSID = bsid || '');
    rb.c$MSID = msid || '';
    //rb.a$uaHash = uaHash || '';
  }

  if (!msid || !bsid) {
    computeHost();
    if (!msid) {
      msid = guidMgr.create();
      // var tEnd = new Date(Date.UTC(9999, 1, 1, 0, 0, 0, 0)).toGMTString();
      setCookies.push(fmt('MSID=%s%s;Version=1;Max-Age=%s;Path=/', msid, host ? (';Domain=.' + host) : '', 10000 * 24 * 60 * 60));
    }
    if (!bsid) {
      bsid = guidMgr.create(getStripe());
      setCookies.push(fmt('BSID=%s%s;Version=1;Path=/', bsid, host ? (';Domain=.' + host) : ''));
    }
  }

  tellOracle();
};