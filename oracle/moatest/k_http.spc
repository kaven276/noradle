create or replace package k_http is
	pragma serially_reusable;

	procedure init;

	procedure set_content_type(p_content_type varchar2 := 'text/html', p_charset varchar2 := null);
	procedure set_content_length(p_length integer);

	procedure set_etag(p_etag varchar2);
	function get_etag return varchar2;

	function str2date(p_str varchar2) return date;
	function date2str(p_date date) return varchar2;

	procedure set_last_modified(p_date date := sysdate);
	function get_if_modified_since return date;

	procedure set_expire(p_date date := sysdate);
	procedure set_expire(p_minutes number);
	procedure set_max_age(p_seconds number);
	procedure set_no_cache;

	procedure disable;
	procedure dump_cache;

end k_http;
/

