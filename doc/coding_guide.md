<script src="header.js"></script>

<div id="title"> PSP.WEB Coding Guide </div>

  I'm sorry that this programming guide is just a skeleton, I'll write details later, but the demo can tell your how to use the API PSP.WEB provide because most of features this doc describe is also covered in DEMO.

Brief Coding Considerations
============================
* use package, not standalone procedure
  - this bring group of pages to reference each other easy
  - this bring group of pages to share common private sub-procedures more easy
  - this support package variables and type definition and packaged cursors
* do not use input parameter, use env parameter by r.xxx API
  - this keep package spec static, not affected by parameter change, isolate recompilation of dependent units
  - this reduce the definition of parameter variables, use r.xxx directly, so reduce code lines
  - this encourage use of filter and common components, they do not to transfer parameters any more
* use %rowtype to easy define local variable, and SQL bind to %rowtype var is concise
* use common reused component that accept sys_refcursor input parameter
* use _ prefixed http parameter for deep parse
* for loop once / exit to quit block immediately
* plan the tag structure of you Noradle page, so pl/sql code need not modified for tag structure change.


Basic PL/SQL programming
==============

features that save the amount of code
--------------

### use of table%rowtype


  Using table%rowtype will eliminate most of the data-structure matching variable declarations, it greatly ease your development than other web development language.

```plsql
procedure a
is
  v table1%rowtype;
  u table2%rowtype;
  w table3%rowtype;
  -- normally 3 rowtype variables is enough
begin
  v.col1 := xxx;
  u.col2 := xxx;
  insert into table1 values v;
  update table2 a set row = u where a.col2 = u.col2;
  w.col1 := v.col1;
  w.col2 := u.col2;
end;
```

	declaration
	sql binding

### use tmp.xxx to save variable declaration

  Using tmp.xxx, you don't need to declare your own local variables for temporary work, such save declaration lines, If you need to a variable to hold the temporary result or staging info, using tmp.xxx is very handy.

```plsql
select count(*) into tmp.cnt from table;
tmp.s := 'This is ';
tmp.s := tmp.s || ' a exmample';
p.p(tmp.s);
tmp.i = 0;
loop
  tmp.i := tmp.i + 1;
  exit when ???
  ...
end loop;
tmp.st := st(1,2,3);
p.ps(tmp.s, tmp.st);
```
	
advanced sql parameter binding
-------------------

  Using PL/SQL, you can embed advanced sql that is far more powerful and convenience than any of the API-based, embed sql or OR-Mapping ways that J2EE, .NET, PHP, Ruby use.

### use returning in sql

  Only in PL/SQL, You can use returning in sql, so you can save a select sql when executing DML.

	update table a set a.col1 = ... where ... returning a.col2 into tmp.s;

### bulk sql

  Normal, you use loop cursor to process data, but you can use bulk sql to do DML more efficiently.

	select bulk collect into tmp.st from table a where ...;
	
### package cursor

  Package cursor can take parameters

	create or replace package test is

		cursor object is
			select * from user_objects a;

		cursor object_by_type(p_type varchar2) is
			select * from user_objects a where a.object_type = p_type;

	end test;
	
other advanced sql that can have better performance and avoid your otherwise complex code
---------
	
### set sql : union, union all, minus, intersect

### hierachical sql

### stats sql

### analytical sql

### sample data sql

	
common sql writing skill
---------------

### Existence Check

  If we scan all rows for existence check, we do waste computing resource, we can break if we meet the first matching row, there are two ways for that, see below:

```plsql
select count(*) into tmp.cnt from table a where a.xxx='???' and rownum=1;
if tmp.cnt=0 then
  -- none exist
else
  -- exist
end if;
```
or
```plsql
for i in (select /*+ first_rows */ from table a where a.xxx='???') loop
  -- exist
  exit; -- quit loop
end loop;
```

  If we want a matching row together, see below:

```plsql
begin
  select a.* into v_row_type_val from table a where a.xxx = '???' and rownum = 1;
  -- exist
exception
  when no_data_found then
    -- none exist
end;
```

layers of code
==============

Compare to J2EE, noradle suggest separate code into boundary(_b), control(_c), entity(_e),
session(_s), hidden(_h) layers.

All pl/sql unit that url can map to must have their names suffix with _b _c or _h.
Noradle forbid to call other suffix unit direct from url mapping, it's for security purpose.

_b (boundary) layer
-------------------

All http get request should map to pl/sql unit whose name suffix with _b.
Large query form can **post** to _b to get the query result.
So for any request that's fetching data or provide page view, should map to xxx_b.xxx package or xxx_b procedure.

_c (control) layer
------------------

If http request want to change(or add/del) data, a _c suffixed plsql unit should do the work.
"_c" plsql unit do form submit checking, authorization checking, insert/update/delete data tables,
and then redirect to a "_b" page or a noradle feedback page.

_h (hidden) layer
------------------

"_h" is called from browser ajax request or just none-browser client, so it's called hidden layer.
The "_h" naming convention tip you the plsql unit is not accessed by normal browser access.

_e (entity) layer
------------------

"_e" plsql unit is optional, if you want encapsulate some pure data/business logic into sql/plsql code,
use "_e" suffix.
When some other client want to access oracle, the "_e" units can be reused for both of it and noradle's _b _c _h unit.

_s (session) layer
------------------
"_s" plsql unit is used to manipulate global-application-context(GAC) as in-db session store.
Because oracle require any GAC namespace to be accessed from specified plsql unit, "_s" suffixed unit should be given
 the right. So any of the browser session data such as login-name, last-access-time can be get/set by "_s" unit.

Naming convention
==============

### unit(package or standalone procedure) suffix naming convention (_b, _c, _h, _e)

* _b is for unit that is read only and generating http result page
* _c is for unit that do data process according to http request info, and guide user to feedback page or next page
* _h is for unit that accept ajax http requests
* _e is for internal(not accessible from url) data manipulation

### specialized package (pv, rcpv, rc)

  Use package pv (or some other short name) to hold package variables.

  Use package rcv to hold any result-cached table rows for the current request

  Use package rc for populating rcv data

### local variable (v,u,w, v_xxx)

* v,u,w for %rowtype
* v_xxx for other local variables

### package variable (gv_xxx)

  PSP.WEB doesn't recommand use of package variables with package body or package code, if you need package variables, do define them in dedicated package specification that do not have a package body. But if you do want it, name it gv_xxx, gv stand for global varaible.

### parameter (p_xxx)

  All DHC layer unit will not have any parameter, then get the http request into through API r, but entity layer unit do have parameters, because entity layer unit will including lot of sql text that will use the parameter as bind variable, to avoid the naming conflicts of table's column names and procedure parameters, PSP.WEB recommand using p_xxx to name parameters, prefix *p_* stand for parameter

basic web developing
==============

basic output using h.xxx API
--------------

This is all h.xxx basic output API specification
```
procedure write_raw(data in out nocopy raw);
procedure write(text varchar2 character set any_cs);
procedure writeln(text varchar2 character set any_cs := '');
procedure string(text varchar2 character set any_cs);
procedure line(text varchar2 character set any_cs := '');
procedure set_line_break(nlbr varchar2);
```

* h.write(varchar2) or h.string(varchar2): write text to http entity content
* h.writeln(varchar2) or h.line(varchar2): write text and newline character(s) to http entity content
* h.set_line_break(nlbr) : set the newline break character(s), usually LF,CR,CRLF
* by default new line use LF or chr(10)

tag/html/xml printing
--------------

* `p.*` : old complex deprecate API
* `x.* (tag.*)` : concise basic tag output, recommended
* `m.* (multi.*)` : concise template repeater, recommended
* `attr.*` : pre set following tag's attributes
* `tagp.*` : use attr.* to fill in its tag's attributes


They are all based on the above h.xxx basic output API.

You can reference their respective documents.

how to write URL
--------------

l(origin_url) -> prefix converted url

### @ stand for name of the current package or standalone procedure, but cut the one type suffix character.
for example, default_b.d is executing,
l('@b.proc1') get default_b.proc1
l('@b/script1.js') get static file for packs/default_b/script1.js

### * stand for the whole name of the pack.proc, but "." is replace with "/"
for example, default_b.d is executing,
l('*.css') get static file for packs/default_b/d.css

### ^ stand for the app/schema's static root
for example, default_b.d is executing,
l('^pub/img/img1.png') get static file for pub/img/img1.png

### \ stand for the site's static root
l('\demo/pub/img/img1.png') get static file for /demo/pub/img/img1.png

### = stand for not change
l('=http://xxx/xxx') converted to http://xxx/xxx

### [key] stand for key/full url lookup in ext_url_v view


get request info by r.xxx API
--------------

All http request info can be accessed from packages -- `r`, `ra`, `rb`.

* `r` is for basic request info
* `ra` is for array request info like headers, cookies
* `rb` is for blob request like request entity body, file uploads

Notice API followed with * is not directly taken from http request info.

For demo code, in demo schema, see `basic_io_b.req_info` procedure.

### get basic request line info

  The request line format is like "http://hostname:port[/base]/dad/pack.proc/path?querystring",
That may be parsed/synthetic/mapped values.

* `r.method` : http request line method like GET, POST, HEAD, ...
* `r.url` : http request url to be accessed, taken directly from request line
* `r.base` : root url path part from where is handled by Noradle, usually null
* `r.dad` : url path part used to map to a database schema/user, usually equal to oracle user name
* `r.dbu`* : which database user/schema the request is mapped to.
* `r.prog` : which plsql store procedure unit the http request is mapped to, or the current entrance unit
* `r.pack` : if map to a package, is's the package name, if map to a standalone procedure, it's null
* `r.proc` : if map to a package, is's the sub procedure name in r.pack, if map to a standalone procedure, it's it
* `r.type` : target procedure suffix like b,c,h
* `r.path` : request url path path that follow the r.prog part
* `r.qstr` : request url's query string part, not including "?"
* `r.url_full`* : full request url that contains "http://dns:port/" part

### http headers

* `ra.headers(name)` : store http header value by header name (header name al stored in lowercase form)
* `r.header(name)` : get http header value by header name (case insensitive)
* `r.ua` : client user-agent string, taken from ra.headers('user-agent')
* `r.referer` : http referer url, taken from ra.headers('referer')
* `r.referer2`* : parameter $referer override ra.headers('referer')
* `r.host`* : host part picked up from http header "host"
* `r.port`* : port part picked up from http header "host", if null, set to 80
* `r.host_prefix`* : if r.host is dns name, it's the leftmost part of dns (parts count must one bigger thant cfg
.host_base_parts to take effect)
tail
parts off
* `r.user`* : http authorization username, taken from http request header "authorization"
* `r.pass`* : http authorization password, taken from http request header "authorization"

### http cookies

* `ra.cookies(name)` : store http cookie value by cookie name
* `r.cookie(name)` : get http cookie value by cookie name (case sensitive)
* `r.msid` : MSID(machine session ID, persisted in browser) cookie value
* `r.bsid` : BSID(browser sssion ID, keep unchanged in a browser session, lost after browser close) cookie value

### http form parameters

1) get form item value by function return

* `r.getc(name,[default]) nvarchar2` : return form item character(nvarchar2) typed value for the name,
optional provide default
* `r.getn(name,[default],format) number` : return form item number typed value for the name, optional provide default
* `r.getd(name,[default],format) date` : return form item date typed value for the name, optional provide default

2) get form item value by "in out nocopy" parameters

* `r.getc(name,inout varchar2,[default])` : set inout var to form item character(nvarchar2) typed value for the name,
optional provide default
* `r.getn(name,inout number,[default],format)` : set inout var to form item number typed value for the name,
optional provide default
* `r.getd(name,inout date,[default],format)` : set inout var to form item date typed value for the name,
optional provide default

3) function that return typed nulls, used in r.getx series's default parameter to avoid overloading confusing.

* `r.nc return varchar2` : provide varchar2 typed null
* `r.nn return number` is : provide number typed null
* `r.nd return date` is : provide date typed null

4) charset used for get character parameter values from original escaped values

* `r.req_charset(cs varchar2)` : r.getc will use "cs"(in oracle db charset names) to get the un-escaped value
* `r.req_charset_db` : r.getc will use db charset to get the un-escaped value
* `r.req_charset_ndb` : r.getc will use db national charset to get the un-escaped value


note 1: if the named form item doesn't exists, and their is no default value provided, noradle will raise exception,
you can catch the exception to show a error page.

note 2: r.getn, r.getd can assign format that's used in to_number,to_date for convert form item values to number and
date, if not used, number will have no format, date format default to "yyyy-mm-dd hh24:mi:ss".

### post body

* `rb.blob_entity` : hold the posted http entity body as oracle blob type, automatically filled for post when it is not
by form submit
* `r.body2clob` : convert the posted http blob into clob type, store in rb.clob_entity
* `r.body2nclob` : convert the posted http blob into nclob type, store in rb.nclob_entity
* `rb.charset_http` : hold mine-type that is in http request header "content-type", if none, default to "UTF-8"
* `rb.charset_db` : converted database charset name from rb.charset_http
* `r.body2auto` : convert the posted http blob into suited type according to mine-type that is in http request header
"content-type", if rb.charset_db is db charset, is same as r.body2clob, if rb.charset_db  is db national charset,
is same as r.body2nclob, otherwise, it does nothing.
* `rb.clob_entity` : hold the converted(by r.body2xxx API) clob typed http entity data
* `rb.nclob_entity` : hold the converted(by r.body2xxx API) nclob typed http entity data

### tcp info
* `r.client_addr` : original client's ip address, if access from a proxy, take from 'x-forwarded-for' request header
* `r.client_port` : original client's port
* `r.peer_addr` : ip address of direct connection client, maybe from browser, maybe from proxy
* `r.peer_port` : port of direct connection client

### for nodejs direct DBCall

Only request parameter(always use utf8) plus internal things include `r.dbu, r.prog, r.pack, r.proc` , could be used.

```
[ This is the basic request info derived from http request line and host http header ]
r.method : GET
r.url : /demo1/basic_io_b.req_info
r.base :
r.dad : demo1
r.prog : basic_io_b.req_info
r.pack : basic_io_b
r.proc : req_info
r.path :
r.qstr :
r.host : qht-test.noradle.com
r.host_prefix : qht-test
r.port : 80
r.url_full : http://qht-test.noradle.com/demo1/basic_io_b.req_info

[ This is the basic request info derived from http header ]
r.ua : Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.57 Safari/537.17
r.referer : http://qht-test.noradle.com/demo1/index_b.dir
r.bsid : nCCTxMxzZoKvH0KYvYAZnQ
r.msid : OJSEnK7GpiBn8clcAWXOTA

[ This is about client address]
r.client_addr : 60.29.143.50
r.client_port : 56905

[ This is all original http request headers ]
accept : text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
accept-charset : GBK,utf-8;q=0.7,*;q=0.3
accept-encoding : gzip,deflate,sdch
accept-language : zh-CN,zh;q=0.8
connection : keep-alive
cookie : MSID=OJSEnK7GpiBn8clcAWXOTA; BSID=nCCTxMxzZoKvH0KYvYAZnQ
host : qht-test.noradle.com
referer : http://qht-test.noradle.com/demo1/index_b.dir
user-agent : Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.57 Safari/537.17
x-forwarded-for : 60.29.143.50
x-forwarded-port : 56905
x-forwarded-proto : http

[ This is all http request cookies ]
BSID : nCCTxMxzZoKvH0KYvYAZnQ
MSID : OJSEnK7GpiBn8clcAWXOTA

[ This is all http request parameter that may be got from the following ways ]
query string, post with application/x-www-form-urlencoded, post with multipart/form-data
```


### get form submit info

  Html form can submit using get or post methods, PSP.WEB can accept them both.

### get the cookie info

### get http request header line inf

advanced topics
==============

http header control with h.xxx API
--------------

### specify response page's charset

### streaming of response

### control caching

### specify response page as other mime-type of doc-type

### take response as file download

### cookie

### ensure response entity's integrity with content-md5

### control request method match the requested PL/SQL unit


<script src="footer.js"></script>
