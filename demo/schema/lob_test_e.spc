create or replace package lob_test_e is

	procedure test
	(
		rcomm varchar2 := 'lob',
		psize pls_integer := 16
	);

	procedure test_all_size;

	procedure do_lob;

	procedure do_varchar2;

	procedure do_raw;

end lob_test_e;
/
