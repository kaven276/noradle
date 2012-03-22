<link type="text/css" rel="stylesheet" href="doc.css" />
<span class="psp_logo">*PSP*.*WEB*<span>
****************************************
<div id="title"> PSP.WEB Coding Guide </div>

  I'm sorry that this programming guide is just a skeleton, I'll write details later, but the demo can tell your how to use the API PSP.WEB provide because most of features this doc describe is also covered in DEMO.

Basic PL/SQL programming
==============

features that save the amount of code
--------------

### use of table%rowtype


  Using table%rowtype will eliminate most of the data-structure matching variable declarations, it greatly ease your development than other web development language.

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

	declaration
	sql binding

### use tmp.xxx to save variable declaration

  Using tmp.xxx, you don't need to declare your own local variables for temporary work, such save declaration lines, If you need to a variable to hold the temporary result or staging info, using tmp.xxx is very handy.

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

	select count(*) into tmp.cnt from table a where a.xxx='???' and rownum=1;
	if tmp.cnt=0 then
		-- none exist
	else
		-- exist
	end if;
	
	or
	
	for i in (select /*+ first_rows */ from table a where a.xxx='???') loop
		-- exist
		exit; -- quit loop
	end loop;

  If we want a matching row together, see below:

	begin
		select a.* into v_row_type_val from table a where a.xxx = '???' and rownum = 1;
		-- exist
	exception
		when no_data_found then
			-- none exist
	end;

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

layers of code
==============
	1. compare to J2EE
	

basic web developing
==============

basic output using h.xxx API
--------------


basic html printing by p.xxx API
--------------

get request info by r.xxx API
--------------

### get basic request line info

### get form submit info

  Html form can submit using get or post methods, PSP.WEB can accept them both.

### get the cookie info

### get http request header line info

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

how to write URL
--------------

advanced p.xxx APIs
--------------

### bulk binding

### extension APIs 

### component css

### scalable css


