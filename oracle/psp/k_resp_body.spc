create or replace package k_resp_body is

	procedure flush;
	function flushed return boolean;

	function written return pls_integer;
	function inc_buf_cnt return pls_integer;
	procedure use_bom(value varchar2);
	procedure download(content in out nocopy blob);
	procedure download(content in out nocopy clob character set any_cs);
	procedure print_init(force boolean := false);

	procedure write_raw(data in out nocopy raw);
	procedure write(text varchar2 character set any_cs);
	procedure writeln(text varchar2 character set any_cs := '');
	procedure string(text varchar2 character set any_cs);
	procedure line(text varchar2 character set any_cs := '');
	procedure w(text varchar2 character set any_cs);
	procedure l(text varchar2 character set any_cs := '');
	procedure iline
	(
		str    varchar2 character set any_cs,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	);
	procedure set_line_break(nlbr varchar2);

	procedure save_pointer;
	function appended return boolean;
	function not_appended return boolean;

	procedure begin_template(nl varchar2 := '');
	procedure end_template(tpl in out nocopy varchar2 character set any_cs);

end k_resp_body;
/
