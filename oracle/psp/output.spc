create or replace package output is

	procedure "_init"(passport pls_integer);

	procedure write_head;

	procedure switch_css;
	procedure css(str varchar2 character set any_cs);
	procedure do_css_write;

	procedure switch;
	procedure line
	(
		str    varchar2 character set any_cs,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	);

	procedure flush;

	procedure finish;

	function get_len return pls_integer;

end output;
/
