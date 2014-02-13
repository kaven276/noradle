/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-5
 * Time: 下午9:01
 */

function noop(){
}

var Noradle = require('..')
  , dbc = new Noradle.DBCall('demo1', 'theOnlyDB')
  , log = console.log
  ;

Noradle.DBCall.init({
  oracle_port : 1522,
  FreeConnTimeout : 60000
});

function UnitTest1(no){
  var limit = Math.pow(10, i);
  dbc.call('db_src_b.example', {limit : limit}, function(status, page, headers){
    console.log("no:", no);
    if (status != 200) {
      console.error('status is', status);
      console.error(page);
      console.error(headers);
      return;
    }
    var rss = Noradle.RSParser.parse(page);

    //log('\n\nthe original result page is :');
    //log(page);
    log('\n\n', 'the parsed result sets is :');
    for (var n in rss) {
      var rs = rss[n];
      log('\n\n', 'ResultSet:', n, '(' + rs.rows.length + ' rows)', 'is :');
      // log(rs);
    }
  });
}
for (var i = 0; i < 5; i++) {
  UnitTest1(i);
}
