create or replace package k_debug is

	procedure meter
	(
		info varchar2,
		name varchar2 := 'prof'
	);

	procedure time_header_init;
	procedure time_header(name varchar2);

	procedure trace
	(
		info varchar2,
		name varchar2 := 'node2psp'
	);

	procedure trace
	(
		info st,
		name varchar2 := 'node2psp'
	);

	procedure set_run_comment(value varchar2);

	procedure req_info;

end k_debug;
/
