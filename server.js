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
      return require('./lib/handlerHTTP.js');
    }
  },
  handlerHTTP : {
    get : function(){
      return require('./lib/handlerHTTP.js');
    }
  },
  handlerFastCGI : {
    get : function(){
      return null;
    }
  },
  NDBC : {
    get : function(){
      return require('./lib/NDBC.js').Class;
    }
  },
  DBPool : {
    get : function(){
      return require('./lib/DBClient.js').DBPool;
    }
  },
  poolMonitor : {
    get : function(){
      return require('./lib/poolMonitor.js');
    }
  },
  inHub : {
    get : function(){
      return require('./lib/inHub.js');
    }
  },

  RSParser : {
    get : function(){
      return RSParser || (RSParser = require('./lib/RSParser.js'));
    }
  },
  gracefulExit : {
    get : function(){
      return require('./lib/util/util.js').gracefulExit;
    }
  }
});
