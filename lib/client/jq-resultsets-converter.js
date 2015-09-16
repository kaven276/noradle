/**
 * Created by cuccpkfs on 15-9-16.
 */

(function(){

  function setup(jQuery, rsParse){

    function jqResultsetsConverter(data){
      if (typeof data == 'string') {
        if (data.substr(-2) == '\x1E\n') {
          data = rsParse(data);
        } else {
          data = jQuery.parseJSON(data);
        }
      }
      if (jQuery.isPlainObject(data)) {
        if (data.$OBJECTS) {
          data = data.$OBJECTS.rows;
        } else if (data.$OBJECT) {
          data = data.$OBJECT.rows.shift();
        }
      }
      return data;
    }

    jQuery.ajaxSetup({
      headers : {
        'Accept' : 'text/resultsets, */*'
      },
      converters : {
        "* text" : window.String,
        "text html" : true,
        "text json" : jqResultsetsConverter,
        "text xml" : jQuery.parseXML
      }
    });
  }

  if (typeof define === 'function' && define.amd) {
    define(['jquery', 'RSParser'], function(jQuery, rsParse){
      setup(jQuery, rsParse);
    });
  } else {
    setup(jQuery, rsParse);
  }

})();

