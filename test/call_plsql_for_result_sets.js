/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-5
 * Time: 下午9:01
 */

require('../lib/cfg.js').oracle_port = 1522;

var Noradle = require('..')
  , DBCall = Noradle.DBCall
  ;
DBCall.init();

function UnitTest(){
  var dbc = new Noradle.DBCall('demo', 'theOnlyDB');
  dbc.call('db_src_b.example', function(status, page, headers){
    console.log('status code is %d', status);
    console.log('\n\nthe original result page is :');
    console.log(page);
    console.log('\n\n', 'the parsed result sets is :');
    var rss = Noradle.RSParser.parse(page);
    for (var n in rss) {
      var rs = rss[n];
      console.log('\n\n', 'ResultSet', n, 'is :');
      console.log(rs);
    }
  });
}
UnitTest();