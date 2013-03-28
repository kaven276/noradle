/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-5
 * Time: 下午5:25
 */

var DBCall
  , RSParser
  , PSP4WEB
  ;

Object.defineProperties(exports, {
  // http handler for PSP(PLSQL Stored Procedure) servlet
  // todo: need include configuration support
  PSP4WEB : {
    get : function(){
      return PSP4WEB || (PSP4WEB = require('./lib/psp.web.js'));
    }
  },
  runPSP4WEB : {
    get : function(){
      return  require('./lib/plsql.js');
    }
  },
  runCombined : {
    get : function(){
      return  require('./lib/combined.js');
    }
  },
  runStatic : {
    get : function(){
      return  require('./lib/static.js');
    }
  },
  runStaticAdv : {
    get : function(){
      return  require('./lib/static_adv.js');
    }
  },
  DBCall : {
    get : function(){
      return DBCall || (DBCall = require('./lib/DBCall.js').Class);
    }
  },
  RSParser : {
    get : function(){
      return RSParser || (RSParser = require('./lib/RSParser.js'));
    }
  },
  ExtHub : {
    get : function(){
      return  require('./lib/ext_hub.js');
    }
  },
  DCOWorkerProxy : {
    get : function(){
      return require('./lib/dco_proxy.js');
    }
  },
  gracefulExit : {
    get : function(){
      return  require('./lib/util.js').gracefulExit;
    }
  }
});
