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
  DBDriver : {
    get : function(){
      return require('./lib/DBDriver3.js').DBDriver;
    }
  },
  dispatcher : {
    get : function(){
      return require('./lib/dispatcher.js');
    }
  },

  RSParser : {
    get : function(){
      return RSParser || (RSParser = require('./lib/RSParser.js'));
    }
  }
});
