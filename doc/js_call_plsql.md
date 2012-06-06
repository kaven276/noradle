
In Noradle(psp.web), you can let javascript call oracle plsql stored procedure, just like below


  var Noradle = require('..');

  Noradle.connectionMonitor.once('connect', UnitTest);

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

In oracle side, the "db_src_b.example" is :

  create or replace package body db_src_b is

  	procedure example is
  		cur sys_refcursor;
  		v1  varchar2(50) := 'psp.web';
  		v2  number := 123456;
  		v3  date := date '1976-10-26';
  	begin
  		if r.call_type = r.ct_http then
  			h.content_type(h.mime_text, 'UTF-8');
  		elsif r.call_type = r.ct_nodejs then
  			h.line('# You are not required to write " h.content_type(h.mime_text, ''UTF-8'') " if call by NodeJS.');
  		end if;

  		h.line('# a stardard psp.web result sets example page');
  		h.line('# It can be used in browser or NodeJS');
  		h.line('# You can use some standard parser or write your own ' ||
  					 'parsers to convert the raw resultsets to javascript data object');
  		h.line('# see PL/SQL source at ' || r.dad_path_full || '/src_b.proc/' || r.prog);
  		open cur for
  			select * from user_objects;
  		rs.print('test', cur);
  		open cur for
  			select v1 as name, v2 as val, v3 as ctime from dual;
  		rs.print('namevals', cur);
  	end;

  end db_src_b;