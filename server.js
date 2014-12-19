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

  servlet : {
    get : function(){
      return require('./lib/server.js');
    }
  },
  NDBC : {
    get : function(){
      return require('./lib/NDBC.js').Class;
    }
  },
  DBPool : {
    get : function(){
      return require('./lib/db3.js').DBPool;
    }
  },
  poolMonitor : {
    get : function(){
      return require('./lib/poolMonitor.js');
    }
  },

  PSP4WEB : {
    get : function(){
      return PSP4WEB || (PSP4WEB = require('./lib/psp.web.js'));
    }
  },
  runPSP4WEB : {
    get : function(){
      return require('./lib/plsql.js');
    }
  },
  runCombined : {
    get : function(){
      return require('./lib/combined.js');
    }
  },
  runStatic : {
    get : function(){
      return require('./lib/static.js');
    }
  },
  runStaticAdv : {
    get : function(){
      return require('./lib/static_adv.js');
    }
  },
  RSParser : {
    get : function(){
      return RSParser || (RSParser = require('./lib/RSParser.js'));
    }
  },
  ExtHub : {
    get : function(){
      return require('./lib/ext_hub.js');
    }
  },
  DCOWorkerProxy : {
    get : function(){
      return require('./lib/dco_proxy.js');
    }
  },
  gracefulExit : {
    get : function(){
      return require('./lib/util.js').gracefulExit;
    }
  }
});
