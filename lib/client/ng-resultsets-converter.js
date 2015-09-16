/**
 * Created by cuccpkfs on 15-9-11.
 * 1. convert raw text/resultsets response body to javascript object
 * 2.
 */

(function(){

  function defineResultsetsConverter(angular, rsParse){
    ngModule = angular.module('ngResultsetsConverter', [])

      .factory('ResultsetsConverter', function(){
        return {
          'request' : function(config){
            if (config.method == 'JSONP') {
              config.url = config.url + '&useraw';
            } else if (config.headers.Accept.match(/application\/json/)) {
              config.headers.Accept = 'text/resultsets' + ', ' + config.headers.Accept;
              // no real effect for JSONP request
            }
            return config;
          },
          'response' : function(response){
            if (response.headers('content-length') == '0') return response;
            if (angular.isObject(response.data)) return response;
            var data = response.data;
            if (angular.isString(data) && data.substr(-2) == '\x1E\x0A') {
              data = rsParse(data);
              if (data.$OBJECTS) {
                data = data.$OBJECTS.rows;
              } else if (data.$OBJECT) {
                data = data.$OBJECT.rows.shift();
              }
            }
            response.data = data;
            return response;
          }
        };
      })

      .config(['$httpProvider', function($httpProvider){
        $httpProvider.interceptors.push('ResultsetsConverter');
      }])
    ;
  }

  if (typeof define === 'function' && define.amd) {
    define(['angular', 'RSParser'], function(angular, rsParse){
      defineResultsetsConverter(angular, rsParse)
    });
  } else {
    defineResultsetsConverter(angular, rsParse);
  }

})();

