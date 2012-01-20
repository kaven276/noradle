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
	procedure content_encoding_identity;
	procedure content_encoding_auto;

	procedure transfer_encoding_chunked;
	procedure transfer_encoding_identity;
	procedure transfer_encoding_auto;

	procedure http_header_close;

	procedure write_head;

	procedure go
	(
		url    varchar2,
		status number := null
	);

end k_http;
/
