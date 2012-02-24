create or replace package k_debug is

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

end k_debug;
/
