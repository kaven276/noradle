create or replace package p is

	procedure "_init"(passport pls_integer);

	procedure line
	(
		str    varchar2,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	);

	procedure flush;

	procedure finish;

end p;
/
