create or replace package k_http is

	mime_text  constant varchar2(30) := 'text/plain';
	mime_xml   constant varchar2(30) := 'text/xml';
	mime_js    constant varchar2(30) := 'application/x-javascript';
	mime_css   constant varchar2(30) := 'text/css';
	mime_word  constant varchar2(30) := 'application/msword';
	mime_excel constant varchar2(30) := 'application/vnd.ms-excel';

	procedure force_stream;
	procedure flush;
	function inc_buf_cnt return pls_integer;
	procedure use_bom(value varchar2);
	procedure write_raw(data in out nocopy raw);
	procedure write(text varchar2 character set any_cs);
	procedure writeln(text varchar2 character set any_cs := '');
	procedure string(text varchar2 character set any_cs);
	procedure line(text varchar2 character set any_cs := '');
	procedure set_line_break(nlbr varchar2);
	procedure save_pointer;
	function appended return boolean;

	procedure status_line(code pls_integer := 200);
	procedure sts_200_ok;
	procedure sts_300_multiple_choices;
	procedure sts_301_moved_permanently;
	procedure sts_302_found;
	procedure sts_303_see_other;
	procedure sts_304_not_modified;
	procedure sts_307_temporary_redirect;
	procedure sts_403_forbidden;
	procedure sts_404_not_found;
	procedure sts_406_not_acceptable;
	procedure sts_409_conflict;
	procedure sts_410_gone;
	procedure sts_500_internal_server_error;
	procedure sts_501_not_implemented;
	procedure sts_503_service_unavailable;

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

	procedure content_encoding_try_zip;
	procedure content_encoding_identity;
	procedure content_encoding_auto;

	procedure content_disposition_attachment(filename varchar2);
	procedure content_disposition_inline(filename varchar2);

	procedure content_language(langs varchar2);
	procedure content_language_none;

	procedure refresh
	(
		seconds number,
		url     varchar2 := null
	);

	procedure expires(expt date);
	procedure expires_now;
	procedure last_modified(lmt date);
	procedure etag(etag varchar2);
	procedure etag_md5_on;
	procedure etag_md5_off;
	procedure etag_md5_auto;
	procedure content_md5_on;
	procedure content_md5_off;
	procedure content_md5_auto;

	procedure header_close;

	procedure go
	(
		url    varchar2,
		status number := null
	);

	procedure retry_after(delta number);
	procedure retry_after(future date);

	procedure www_authenticate_basic(realm varchar2);
	procedure www_authenticate_digest(realm varchar2);

	procedure allow_get;
	procedure allow_post;
	procedure allow_get_post;
	procedure allow(methods varchar2);

	procedure check_if_not_modified_since;

	procedure set_cookie
	(
		name    in varchar2,
		value   in varchar2,
		expires in date default null,
		path    in varchar2 default null,
		domain  in varchar2 default null,
		secure  in boolean default false
	);

end k_http;
/
