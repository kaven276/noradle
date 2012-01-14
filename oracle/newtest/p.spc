create or replace package p is

	procedure "_init"
	(
		conn     in out nocopy utl_tcp.connection,
		passport pls_integer
	);

	procedure status_line(code pls_integer := 200);

	procedure write_header
	(
		name  varchar2,
		value varchar2
	);

	procedure location(url varchar2);

	procedure content_type
	(
		mime_type varchar2 := 'text/html',
		charset   varchar2 := 'UTF-8'
	);

	procedure http_header_close;

	procedure go(url varchar2);

	procedure line(str varchar2);

	procedure flush;

end p;
/
