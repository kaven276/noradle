/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-5
 * Time: 下午9:01
 */

function noop(){
}

var Noradle = require('noradle')
  , log = console.log
  , parse = Noradle.RSParser.rsParse
  , servlet = 'demo1.db_src_b.example'
  , inspect = require('util').inspect
  ;

// servlet = 'question.test_b.ds_post_tree';


// var tar = [9001, 'localhost'];
// var tar = [8001, 'noradle.com'];
// var tar = ['/tmp/inhub'];
var tar = [9009, 'localhost'];
var dbPool = Noradle.DBDriver.connect(tar, {
  cid : 'test',
  passwd : 'test'
});
var dbc = new Noradle.NDBC(dbPool, {
  param1 : 'value1',
  param2 : 'value2',
  __parse : true
});

function UnitTest1(no){
  var limit = Math.pow(10, no);
  dbc.call(servlet, {limit : limit}, function(status, headers, page){
    console.log("no:", no);
    if (status != 200) {
      console.error('status is', status);
      console.error(page);
      console.error(headers);
      return;
    }
    log(page);
    if (page instanceof String) {
      console.log(inspect(parse(page), {depth : 8}));
    } else {
      console.log(inspect(page, {depth : 8}));
    }

  });
}

for (var i = 1; i <= 1; i++) {
  UnitTest1(i);
}
