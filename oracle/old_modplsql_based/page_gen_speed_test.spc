create or replace package page_gen_speed_test is

	procedure allt
	(
		p_total_size   number,
		p_line_size    pls_integer,
		p_lobpage_size pls_integer
	);

	procedure static2local(cnt number := 1000000);

	procedure str2;

	procedure lob_aligned_test;

	procedure lob_append;

end page_gen_speed_test;
/

