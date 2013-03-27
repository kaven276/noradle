create or replace package tests is
	pragma serially_reusable;

	procedure arr_compare(amount pls_integer := 100);
	procedure str_len_compare;
	procedure simple_arr_compare;

	procedure serial_reuse_outer;
	procedure serial_reuse_inner;
	
	procedure indexby_exist;
end tests;
/
