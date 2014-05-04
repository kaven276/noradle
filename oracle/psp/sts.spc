create or replace package sts is

	attr  varchar2(4000);
	stack varchar2(4000);

	gv_st     st;
	gv_texts  st;
	gv_values st;

	olevel pls_integer;
	pretty boolean;

end sts;
/
