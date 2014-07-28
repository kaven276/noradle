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


Part 2 : call in db driver
======

```javascript
  dbc.call('db_src_b.example', function(status, page, headers){
    console.log("no:", no);
    if (status != 200) {
      console.error('status is', status);
      console.error(page);
      console.error(headers);
      return;
    }
    // got some result sets
    var rss = Noradle.RSParser.parse(page);

    log(page);
    log('\n\n', 'the parsed result sets is :');
    for (var n in rss) {
      var rs = rss[n];
      log('\n\n', 'ResultSet:', n, '(' + rs.rows.length + ' rows)', 'is :');
      log(rs);
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

Part 3 : call out net proxy
======

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