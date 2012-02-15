create or replace package k_http is

	procedure status_line(code pls_integer := 200);
	procedure sts_501_not_implemented;

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

	procedure content_disposition_attachment(filename varchar2);
	procedure content_disposition_inline(filename varchar2);

	procedure content_language(langs varchar2);
	procedure content_language_none;

	procedure refresh
	(
		seconds number,
		url     varchar2 := null
	);

	procedure last_modified(lmt date);
	procedure etag(etag varchar2);
	procedure etag_md5;
	procedure content_md5;

	procedure http_header_close;

	procedure write_head;

	procedure go
	(
		url    varchar2,
		status number := null
	);

	procedure retry_after(delta number);
	procedure retry_after(future date);

	procedure www_authenticate_basic(realm varchar2);
	procedure www_authenticate_digest(realm varchar2);

end k_http;
/
