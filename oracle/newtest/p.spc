create or replace package p is

	procedure "_init"
	(
		passport pls_integer
	);

	procedure line(str varchar2);

	procedure flush;

	procedure finish;

end p;
/
