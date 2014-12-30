Noradle is for Node & Oracle integration. Noradle has three large parts.


The work at Now
==========

  Check installation scripts and demos, improve documetation. prepare to v0.2 release.

Overview
==========

1. psp.web. NodeJS act as http gateway to convert and pass http request data onto oracle PL/SQL procedure and receive and transfer back what the PL/SQL produce.
2. call in db driver. Provide javascript API to access PL/SQL page and facilities to product result sets and convert them into javascript objects.
3. call out net proxy. NodeJS can use PL/SQL API to send messages to any server through NodeJS router proxy and professional proxy and get the response messages in-process or out-process.

Part 1 : psp.web
==========

```plsql

 procedure show_user_name is
   v user_tab%rowtype
  begin
    v.user_id := r.getc('uid');
    select a.* into v from user_tab a where a.user_id = v.user_id;
    h.write('hello ' || v.user_name);
  end;

  // access http://host/dbu/show_user_name?uid=xxx then

```

please see [Introduction](doc/introduction.md) at doc/introduction.md on github (format will lose)

please see [Documentation Index](http://docs.noradle.com/index.html) at my site

please see [Introduction](http://docs.noradle.com/introduction.html) at my site

please see [Deployment](http://docs.noradle.com/deployment.html) at my site

please see [API demo](http://unidialbook.com/demo) at my demo site

please see [Basic Coding Guide of Noradle](http://docs.noradle.com/coding_guide.html)

please see [SAAS app "dialbook" developed on Noradle](http://unidialbook.com/com)  (you can use any mobile number
11digits to login)

please see [License of PSP.WEB](http://docs.noradle.com/license.html) at doc/license.md


Part 2 : NDBC (node database connectivity)
======

```javascript

var Noradle = require('..')
  , parse = Noradle.RSParser.rsParse
  , inspect = require('util').inspect
  ;

var dbPool = new Noradle.DBPool(1522, {
  FreeConnTimeout : 60000
});

var dbc = new Noradle.NDBC(dbPool, {
  x$dbu : 'demo',
  __parse : true
});

dbc.call('db_src_b.example', {limit : 10}, function(status, headers, page){
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


```

```plsql
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
			-- h.header('x-template', 'users');
			h.line('# You are not required to write " h.content_type(h.mime_text, ''UTF-8'') " if call by NodeJS.');
		end if;

		h.line('# a stardard psp.web result sets example page');
		h.line('# It can be used in browser or NodeJS');
		h.line('# You can use some standard parser or write your own ' ||
					 'parsers to convert the raw resultsets to javascript data object');
		h.line('# see PL/SQL source at ' || r.dir_full || '/src_b.proc/' || r.prog);

		open cur for
			select a.object_name, a.subobject_name, a.object_type, a.created
				from user_objects a
			 where rownum <= r.getn('limit', 8);
		rs.print('test', cur);

		open cur for
			select v1 as name, v2 as val, v3 as ctime from dual;
		rs.print('namevals', cur);
	end;

end db_src_b;

```

please see [Call oracle plsql stored procedure with javascript](http://docs.noradle.com/js_call_plsql.html) at
doc/js_call_plsql.md

### use repeated NDBC call to pull message from oracle:

```javascript

var Noradle = require('noradle')
  , log = console.log
  , inspect = require('util').inspect
  ;

var dbPool = new Noradle.DBPool(1522, {
    FreeConnTimeout : 60000
  })
  , callout = new Noradle.NDBC(dbPool, {
    __parse : true,
    __repeat : true,
    __parallel : 1,
    __ignore_error : true,
    x$dbu : 'public',
    timeout : 1
  })
  , callin = new Noradle.NDBC(dbPool, {
    x$dbu : 'public'
  })
  ;

callout.call('mp_h.pipe2node', {pipename : 'pipe_only'}, function(status, headers, p){
  var pipename = p.pop()
    , oper = p[0]
    , p1 = parseInt(p[1])
    , p2 = parseInt(p[2])
    , result
    ;
  console.log('callout input params', p);
  if (pipename) {
    switch (oper) {
      case 'add':
        result = p1 + p2;
        break;
      case 'minus':
        result = p1 - p2;
        break;
      case 'multiply':
        result = p1 * p2;
        break;
      default:
        result = 0;
    }
    // need call back with response to oracle
    callin.call('mp_h.node2pipe', {
      h$pipename : pipename,
      oper : oper,
      result : result
    });
  }
});
```

```plsql

﻿procedure multiple_callout_easy_resp is
  v_result    number;
  v_rpipename varchar2(100) := r.cfg || '.' || r.slot;
  p1          number := r.getn('p1', 5);
  p2          number := r.getn('p2', 3);
  v_oper      varchar2(30);
  v_opers     varchar2(100);
  v_add       number;
  v_minus     number;
  v_multiply  number;
begin
  -- clear receive reponse pipe first
  dbms_pipe.purge(v_rpipename);

  -- callout 1
  dbms_pipe.pack_message('add');
  dbms_pipe.pack_message(p1);
  dbms_pipe.pack_message(p2);
  dbms_pipe.pack_message(v_rpipename);
  tmp.n := dbms_pipe.send_message('pipe_only');

  -- callout 2
  dbms_pipe.pack_message('minus');
  dbms_pipe.pack_message(p1);
  dbms_pipe.pack_message(p2);
  dbms_pipe.pack_message(v_rpipename);
  tmp.n := dbms_pipe.send_message('pipe_only');

  -- callout 3
  dbms_pipe.pack_message('multiply');
  dbms_pipe.pack_message(p1);
  dbms_pipe.pack_message(p2);
  dbms_pipe.pack_message(v_rpipename);
  tmp.n := dbms_pipe.send_message('pipe_only');

  -- receive all the callout response, with any order
  for i in 1 .. 3 loop
    if not mp.pipe2param(v_rpipename, 15) then
      -- callout timeout
      h.status_line(400);
      x.t('callout timeout!');
      return;
    end if;
    v_oper   := r.getc('oper');
    v_result := r.getn('result');

    v_opers := v_opers || v_oper || ',';
    case v_oper
      when 'add' then
        v_add := v_result;
      when 'minus' then
        v_minus := v_result;
      when 'multiply' then
        v_multiply := v_result;
      else
        null;
    end case;
  end loop;

  x.p('<p>', 'p1:' || p1);
  x.p('<p>', 'p2:' || p2);
  x.p('<p>', 'response receive order:' || v_opers);
  x.p('<p>', 'add:' || v_add);
  x.p('<p>', 'minus:' || v_minus);
  x.p('<p>', 'multiply:' || v_multiply);
end;

```

Part 3 : call out net proxy
======

  The "call out proxy facility" is still usable, but it's depleted,
use repeated NDBC call to monitor call-out messages,
use normal NDBC call to write back call-out response to oracle.


```plsql

// give ip,port, call agent/proxy to get mobile telephone number
﻿dco.line(p_cli_ip);
dco.line(p_cli_port);
v_req := dco.send_request(3);
if dco.read_response(v_req, v_res, 2) then
  v_rcode := to_number(pdu.get_char_line);
  v_telen := pdu.get_char_line;
  pdu.clear;
  cv.telen_abtime := t.tf(v_rcode in (100, -15), sysdate, null);
  return v_telen;
else
  return null;
end if;

```

```javascript

Noradle.DCOWorkerProxy.createServer(findMobileNumber).listen(cfg.proxy_port);

function findMobileNumber(dcoReq, dcoRes){
  var lines = req.content.toString('utf8').split('\n')
    , client_ip = lines.shift()
    , client_port = lines.shift()
    ;
  ...
  dcoRes.write(resultCode.toString() + '\n');
  dcoRes.write(telen + '\n');
  dcoRes.end();
}

```

please see [call external service from PL/SQL on Noradle](http://docs.noradle.com/direct_call_out.html) at
my introduction site