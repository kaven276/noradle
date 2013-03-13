create or replace package output is

	procedure "_init"(passport pls_integer);

	procedure write_head;

	procedure switch_css;
	procedure css(str varchar2);
	procedure do_css_write;

	procedure line
	(
		str    varchar2 character set any_cs,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	);

	function prevent_flush(text varchar2) return boolean;
	procedure flush;

	procedure finish;

end output;
/
