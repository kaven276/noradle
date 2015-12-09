create or replace package sts is

	attr  varchar2(4000);
	stack varchar2(4000);

	gv_cuts   st;
	gv_texts  st;
	gv_values st;

	olevel pls_integer;
	pretty boolean;

	tagn  varchar2(30);
	lstr varchar2(4000);
	rstr varchar2(32767);

end sts;
/
