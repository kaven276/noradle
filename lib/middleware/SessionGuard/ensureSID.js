/**
 * Created by cuccpkfs on 14-12-12.
 */

var guidMgr = require('./guidMgr.js')
  , fmt = require('util').format
  , mGuard = require('./SidGuard.js')
  , onGeneralError = require('./../../error_pages.js').onGeneralError
  , debug = require('debug')('noradle-ensure-sid')
  ;

module.exports = function ensureSID(req, res, bakRes, rb, cfg){
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
  debug('1.fstReq,msid,bsid', req.url, fstReq, msid, bsid);
  delete cookies['GUARD' + port];
  res.setHeader('Set-Cookie', setCookies);

  if (bsid && cfg.check_session_hijack) {
    try {
      if (newGuard = mGuard.checkUpdate(host, bsid, guard, rb.a$caddr)) {
        writeHead = bakRes.writeHead;
        bakRes.writeHead = function(sts, headers){
          if (typeof newGuard === 'function') {
            newGuard = newGuard();
          }
          setCookies.push(fmt('GUARD%d=%s;Version=1;Path=/', port, newGuard));
          writeHead.call(bakRes, sts, headers);
        };
      }
    } catch (e) {
      (onGeneralError(res))(e);
      return false;
    }
  }

  // UA is not browser and not require session or browser not allow cookie
  if (ua.match(cfg.NoneBrowserPattern)) {
    tellOracle();
    return true;
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
    debug('2.fstReq,msid,bsid,c$msid,c$bsid', req.url, fstReq, msid, bsid, rb.c$MSID, rb.c$BSID, setCookies);
  }

  if (!msid || !bsid) {
    debug(msid, bsid);
    if (!msid) {
      msid = guidMgr.create();
      // var tEnd = new Date(Date.UTC(9999, 1, 1, 0, 0, 0, 0)).toGMTString();
      setCookies.push(fmt('MSID=%s;Version=1;Max-Age=%s;Path=/;httpOnly', msid, 10000 * 24 * 60 * 60));
    }
    if (!bsid) {
      bsid = guidMgr.create(getStripe());
      setCookies.push(fmt('BSID=%s;Version=1;Path=/;httpOnly', bsid));
    }
  }

  tellOracle();
};