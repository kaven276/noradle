Noradle is for Node & Oracle integration,
with the aid of Node,
just write nearly all business logic in a infomation system in PL/SQL store procedure code,
node, in front of oracle, provide access to oracle by HTTP,
and node javascript code can access oracle directly by noradle NDBC,
oracle plsql can send out message to node by repeat NDBC call.

The formal repository name is 'noradle',
**all-node-oracle** is just a synonym used for npm search and github search,
never `npm install all-node-oracle`.

see [noradle](https://github.com/kaven276/noradle) for latest version in github.

see [noradle](https://www.npmjs.com/package/noradle) for latest npm publishment in npm registry.

The work at Now
==========

  Sorry for long time of broken install scripts and demos.
I have just checked installation scripts and demos,
they are passed test for initial and overlap installation,
demo app work fine.

  But documentation may be somewhat old,
not sync with the very latest work.
See demo first, and I'm rushing to make a set of refreshed documentation.
But noradle is not a small utility project,
it's a full oracle-node-based server-side information system architecture,
it have a framework and library API.
Through it's more easy to develope/maintain a oracle-based information system,
complete and concise documentation require big effort.

##  The recent changes are list below:

* use node-store-based session, remove oracle GAC(global application context) based session store.
support session across different oracle instances among RAC instances, data-guard nodes, distributed databases
* oracle result-cache refresh mechanism prefer user session marker based update checker
* no longer rely on GAC for features, so oracle GAC memeory overlow will never occur, no GA required
* obsolete old complex printing/url API p(k_xhtp)/u, add new concise print API(x,m,tb,tr,sty,l)
that servlet code is formatted well for both plsql code and html/xml code
* noradle core have fine architecture, split to layers, servlet engine is just a http handler,
and can be easy integrated to connect/express like environment.
* support response filter plugin architecture, now support lines/resultsets format converters.
* All none core features is removed or refactored as internal plugins.
* old DCO(exthub+worker) call-out mechanism is removed,
use repeated NDBC call-in to listen to pipe message(as call-out request header/body)



##  The noradle project is now advanced to v0.10.x release.

## Roadmap:

* one DBPool instance can hold oracle connections from different oracle instance among RAC, data-guard, distributed db.
and one request can route to the right connect among them.
* Good response caching, server cache that can serve requests even if it's session controled page.
* GAC based result cache version updater
*
* connection tunnel that let oracle to connect to node front positioned behind NAT
* better file upload/post design

Overview
==========

1. psp.web. NodeJS act as http gateway to convert and pass http request data onto oracle PL/SQL procedure
and receive and transfer back what the PL/SQL produce.
2. call in db driver. Provide javascript API to access PL/SQL page and facilities to product result sets
and convert them into javascript objects.
3. call out facility as repeated call in listen for new messages.

see [Introduction](http://docs.noradle.com/introduction.html) for more intro.

see [Noradle's Goal](http://docs.noradle.com/NoradleGoal.html) to understand what noradle aim for.

`cd ./demo && node server.js` will start demo server.
or see ready demo server at http://unidialbook.com/demo.
All noradle features are shown in demo app.

Installation
===========================

### Prequirement

* Oracle Instant Client or Any Oracle Client is installed first
* Python, used by node-gyp
* C++ Compiler toolchain (GCC, Visual Studio or similar)
* set ENV variables OCI_LIB_DIR, OCI_INCLUDE_DIR, OCI_VERSION, NLS_LANG
* Create symlinks for libclntsh and libocci
* (Linux) Install libaio
* Configure the dynamic library path on your platform to include $OCI_LIB_DIR

**No No No, all items in the above list is not required at all.**

  All you need to install on is just node and oracle,
there are no any types of oracle client driver required,
nor oracle instant client required.
If you can install node and oracle on your server on any OS,
you can install noradle on your server.

### install on OS filesystem and ORACLE database

  Noradle will install two parts:

* one is node javascript code,
run on top of node,
`npm -g install noradle` is ok.
* the other is oracle schema units,
install/run on top of oracle database.
`cd oracle && sqlplus "/ as sysdba" @install.sql` will create supporting schema and its objects in oracle database.

see [Deployment](http://docs.noradle.com/deployment.html) for detailed info.

Part 1 : psp.web (plsql http servlet)
==========

## very basic demo

  The very basic demo that use `r.getc` to get request parameter,
call `h.write` to print response body.


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

see [noradle-demo](https://github.com/kaven276/noradle-demo) 'server.js'
for how to integrate a noradle servlet engine to a node http server.

##  Noradle support concise printing API as below:

* x(tag) print jade like tag for xml/xhtml
* m(multi) multiply template with array
* tb(list) quick print table
* tr(tree) quick print hierachical/nested tags/data
* sty(style) embed/link css
* l(url) link other resouce with concise code

see demo app for all of above.

## documentation links

_Note: doc content may be old or obsolete._

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

`rs.print(name, sys_refcursor)` can print a named SQL result set that is compact formatted.

### The node javascript client who call in oracle plsql servlet

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

### The oracle plsql sevlet code who generate SQL result sets

```plsql
create or replace package body db_src_b is

	procedure example is
		cur sys_refcursor;
		v1  varchar2(50) := 'psp.web';
		v2  number := 123456;
		v3  date := date '1976-10-26';
	begin
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

### The compact result sets response lines separated by hidden ASCII and linefeed/comma chars.

```text
[test]
OBJECT_NAME:1,SUBOBJECT_NAME:1,OBJECT_TYPE:1,CREATED:12
MEDIA_B,,PACKAGE,2014-05-13 11:31:37
MEDIA_B,,PACKAGE BODY,2014-05-13 11:31:37
LIST_B,,PACKAGE,2014-07-04 11:32:16
LIST_B,,PACKAGE BODY,2014-07-04 11:32:16
ATTR_TAGP_DEMO_B,,PACKAGE,2014-07-04 15:49:37
ATTR_TAGP_DEMO_B,,PACKAGE BODY,2014-07-04 15:50:04
STYLE_B,,PACKAGE,2014-07-03 09:40:08
STYLE_B,,PACKAGE BODY,2014-07-03 09:45:21
PO_IFRAME_B,,PACKAGE,2014-10-10 10:56:41
PO_IFRAME_B,,PACKAGE BODY,2014-10-10 10:56:43

[namevals]
NAME:1,VAL:2,CTIME:12,P1:1,P2:1,PNULL:1
psp.web,123456,1976-10-26 00:00:00,value1,value2,

```

### More

Result sets print support main-sub table data print, can be synthesized to hierachical javascript/JSON object.

please see [Call oracle plsql stored procedure with javascript](http://docs.noradle.com/js_call_plsql.html) at
doc/js_call_plsql.md



Part 3 : call out net proxy
======

  The "call out proxy facility" is depleted,
use repeated NDBC call to monitor call-out messages,
use normal NDBC call to write back call-out response to oracle.

  The two demos below use repeated NDBC call to pull message from oracle.

## use named pipe, sep by line message format, direct send pipe demo

### The node javascript client who listen call-out message from oracle plsql servlet

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

### the plsql servet that generate call-out message using dbms_pipe directly

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

## use default named pipe, sep by line message format, use standard print API to generate request demo

### The node javascript client who listen call-out message from oracle plsql servlet

``` javascript

var Noradle = require('noradle')
  , log = console.log
  , inspect = require('util').inspect
  ;

var dbPool = new Noradle.DBPool(1522, {
  FreeConnTimeout : 60000
});
var callout = new Noradle.NDBC(dbPool, {
  __repeat : true,
  __parallel : 1,
  __ignore_error : false,
  __parse : true,
  timeout : 1
});

var callin = new Noradle.NDBC(dbPool, {});

/**
 * you can fetch multiple types of call-out messages from one named pipe
 * use header to differentiate them
 */
callout.call('demo.mp_h.fetch_msg', function(status, headers, message){
  var msgType = headers['Msg-Type'];
  switch (msgType) {
    case 'type1':
      console.log('type 1 message received.');
      break;
    case 'type2':
      console.log('type 2 message received.');
      break;
    case 'type3':
      console.log('type 3 message received.');
      break;
    case 'type4':
      console.log('type 4 message received.');
      // mimic call external service to get result and send it back to oracle as synchronized call return value
      setTimeout(function(){
        callin.call('demo1.mp_h.node2pipe', {h$pipename : headers['Callback-Pipename'], temperature : -3});
      }, 1000);

      break;
  }
  console.log(headers);
  console.log(message);
});
```

### the plsql servet that generate call-out message using standard printing API between `mp.begin_msg` and `mp.send_msg`

``` plsql
procedure sync_sendout4 is
begin
  x.p('<p>', 'a call-out message is send as this page is produced!');
  mp.begin_msg;
  mp.set_callback_pipename;
  h.header('Content-Type', 'text/items');
  h.header('Msg-Type', 'type4');
  h.line('Tianjin');
  mp.send_msg;

  if not mp.pipe2param then
    h.status_line(504);
    x.t('callout(get termperature) timeout!');
    return;
  end if;
  x.t('temperature is ' || r.getn('temperature') || ' degree');
end;
```

### ECO-System

* see [noradle-demo](https://github.com/kaven276/noradle-demo)
for example app of noradle
that use http servlet, NDBC call, call-out features.
* see [noradle-cm](https://github.com/kaven276/noradle-cm)
for how to do *Software Configuration Management* with noradle app(PLSQL app).
* see [unidialbook](http://unidialbook.com)
for a noradle based production app.
It's a chinese language SAAS web app that serve address book for group customers,
developed for China Unicom(Tianjin).
And unidialbook have some shared plugin app like EXAM, they are all noradle based.