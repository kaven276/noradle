<link type="text/css" rel="stylesheet" href="doc.css" />
<span class="psp_logo">*PSP*.*WEB*<span>
****************************************

<div id="title"> Call Oracle PL/SQL stored procedure with javascript in NodeJS  </div>

  The PSP.WEB software is tested on ORACLE DATABASE 11g（EE & XE) and NodeJS v0.6.2.

Introduction
===============================================================

  Noradle is not limited to gateway the PL/SQL server pages, but can do more.

1. let javascript to call oracle plsql procedure for result, <br/>
 or just submit data through parameters or request body
2. let javascript to call oracle message stream procedure for catching database event/message/command instantly <br/>
 so it can be used for oracle to call NodeJS proxy for any external call, </br>
 this way, Noracle extend oracle db for its lack of external access ability

Call for result page and convert the page to result sets
===============================================================

In Noradle(psp.web), you can let javascript call oracle plsql stored procedure, just like the code example as below

```
var Noradle = require('..')
  , dbc = new Noradle.DBCall('demo', 'theOnlyDB')
  ;
Noradle.DBCall.init({oracle_port : 1523});

function UnitTest(){
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
      console.log('\n', 'ResultSet', n, 'is :');
      console.log(rs);
    }
  });
}
UnitTest();
UnitTest();
UnitTest();
```


In oracle side, the `"db_src_b.example"` is :

```
create or replace package body db_src_b is

	procedure example is
		cur sys_refcursor;
		v1  varchar2(50) := 'psp.web';
		v2  number := 123456;
		v3  date := date '1976-10-26';
	begin
		if r.call_type = 'HTTP' then
			h.content_type(h.mime_text, 'UTF-8');
		elsif r.call_type = 'DATA' then
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

```

  The result log is as this:

```
status code is 200


the original result page is :
# You are not required to write " h.content_type(h.mime_text, 'UTF-8') " if call by NodeJS.
# a stardard psp.web result sets example page
# It can be used in browser or NodeJS
# You can use some standard parser or write your own parsers to convert the raw resultsets to javascript data object
# see PL/SQL source at :////src_b.proc/db_src_b.example

[test]
OBJECT_NAME:1,SUBOBJECT_NAME:1,OBJECT_ID:2,DATA_OBJECT_ID:2,OBJECT_TYPE:1,CREATED:12,LAST_DDL_TIME:12,TIMESTAMP:1,STATUS:1,TEMPORARY:1,GENERATED:1,SECONDARY:1,NAMESPACE:2,EDITION_NAME:1
TERM_T,,73612,73612,TABLE,2012-04-10 09:47:12,2012-04-10 09:47:12,2012-04-10:09:47:12,VALID,N,N,N,1,
PK_TERM,,73613,73613,INDEX,2012-04-10 09:47:13,2012-04-10 09:47:13,2012-04-10:09:47:13,VALID,N,N,N,4,
USER_T,,73614,73614,TABLE,2012-04-10 09:47:13,2013-03-27 20:42:49,2012-04-10:09:47:13,VALID,N,N,N,1,
...

[namevals]
NAME:1,VAL:2,CTIME:12
psp.web,123456,1976-10-26 00:00:00


 the parsed result sets is :


 ResultSet test is :
{ name: 'test',
  attrs:
   [ { name: 'OBJECT_NAME', dataType: '1' },
     { name: 'SUBOBJECT_NAME', dataType: '1' },
     { name: 'OBJECT_ID', dataType: '2' },
     { name: 'DATA_OBJECT_ID', dataType: '2' },
     { name: 'OBJECT_TYPE', dataType: '1' },
     { name: 'CREATED', dataType: '12' },
     { name: 'LAST_DDL_TIME', dataType: '12' },
     { name: 'TIMESTAMP', dataType: '1' },
     { name: 'STATUS', dataType: '1' },
     { name: 'TEMPORARY', dataType: '1' },
     { name: 'GENERATED', dataType: '1' },
     { name: 'SECONDARY', dataType: '1' },
     { name: 'NAMESPACE', dataType: '2' },
     { name: 'EDITION_NAME', dataType: '1' } ],
  rows:
   [ { OBJECT_NAME: 'TERM_T',
       SUBOBJECT_NAME: '',
       OBJECT_ID: '73612',
       DATA_OBJECT_ID: '73612',
       OBJECT_TYPE: 'TABLE',
       CREATED: '2012-04-10 09:47:12',
       LAST_DDL_TIME: '2012-04-10 09:47:12',
       TIMESTAMP: '2012-04-10:09:47:12',
       STATUS: 'VALID',
       TEMPORARY: 'N',
       GENERATED: 'N',
       SECONDARY: 'N',
       NAMESPACE: '1',
       EDITION_NAME: '' },
		...
		]

 ResultSet namevals is :
{ name: 'namevals',
  attrs:
   [ { name: 'NAME', dataType: '1' },
     { name: 'VAL', dataType: '2' },
     { name: 'CTIME', dataType: '12' } ],
  rows: [ { NAME: 'psp.web', VAL: '123456', CTIME: '1976-10-26 00:00:00' } ] }
```

**********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>