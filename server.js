/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-5
 * Time: 下午5:25
 */

var RSParser
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
