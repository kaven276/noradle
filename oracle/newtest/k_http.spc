create or replace package k_http is

	procedure status_line(code pls_integer := 200);

	procedure header
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

	procedure content_encoding_gzip;
	procedure content_encoding_none;

	procedure transfer_encoding_chunked;
	procedure transfer_encoding_none;

	procedure http_header_close;

	procedure write_head;

	procedure go(url varchar2);

end k_http;
/
