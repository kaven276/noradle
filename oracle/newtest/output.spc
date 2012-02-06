create or replace package output is

	procedure "_init"(passport pls_integer);

	procedure css(str varchar2);

	procedure line
	(
		str    varchar2,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	);

	procedure flush;

	procedure finish;
  
  procedure do_write(v_len in integer, v_gzip in boolean);

end output;
/
