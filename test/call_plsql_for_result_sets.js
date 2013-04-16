/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-5
 * Time: 下午9:01
 */

var Noradle = require('..')
  , dbc = new Noradle.DBCall('demo', 'theOnlyDB')
  ;
Noradle.DBCall.init({oracle_port : 1523});

function UnitTest1(){
  dbc.call('db_src_b.example', function(status, page, headers){
    console.log('status code is %d', status);
    if (status != 200) {
      console.error('status is', status);
      return;
    }
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
UnitTest1();
UnitTest1();
UnitTest1();
UnitTest1();