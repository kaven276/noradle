create or replace package k_debug is

	procedure meter
	(
		info varchar2,
		name varchar2 := 'prof'
	);

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

end k_debug;
/
