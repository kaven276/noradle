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
      return require('noradle-http');
    }
  },
  handlerHTTP : {
    get : function(){
      return require('noradle-http');
    }
  },
  HTTP : {
    get : function(){
      return require('noradle-http');
    }
  },
  handlerFastCGI : {
    get : function(){
      return null;
    }
  },
  FCGI : {
    get : function(){
      return null;
    }
  },
  NDBC : {
    get : function(){
      return require('noradle-ndbc').Class;
    }
  },
  DBDriver : {
    get : function(){
      return require('noradle-nodejs-client').DBDriver;
    }
  },
  dispatcher : {
    get : function(){
      return require('noradle-dispatcher');
    }
  },

  RSParser : {
    get : function(){
      return RSParser || (RSParser = require('noradle-resultsets'));
    }
  }
});
