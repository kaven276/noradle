create or replace package body k_http is
	pragma serially_reusable;

	gv_disabled boolean := false;
	gc_date_format constant varchar2(100) := 'Dy, DD Mon YYYY HH24:MI:SS "GMT"';
	gc_date_lang   constant varchar2(100) := 'NLS_DATE_LANGUAGE = American';

	gv_last_modified date;
	gv_max_age       number;
	gv_expire        date;
	gv_etag          varchar2(55);

	gv_compute_digest boolean := false;
	gv_no_cache       boolean := false;
	-- 0 stand for close expire
	-- 1 stand for follow program's setting
	-- null stand for system automatic setting following system dynamic load (future feature)
	-- <1 stand for scale down the expire time, more load but more freshness
	-- >1 stand for scale up the expire time, less load and but more staleness

	procedure init is
	begin
		null;
	end;

	procedure set_content_type(p_content_type varchar2 := 'text/html', p_charset varchar2 := null) is
	begin
		if p_charset is null then
			htp.p('Content-type: ' || p_content_type);
		else
			htp.p('Content-type: ' || p_content_type || '; charset=' || p_charset);
		end if;
		return;
		owa_util.mime_header(ccontent_type => p_content_type, bclose_header => false,
												 ccharset => nvl(p_charset, utl_i18n.map_charset(owa_util.get_cgi_env('REQUEST_CHARSET'))));
	end;

	procedure set_content_length(p_length integer) is
	begin
		htp.p('Content-Length: ' || to_char(p_length));
	end;

	procedure set_location(p_url varchar2) is
	begin
		owa_util.redirect_url(p_url, false);
	end;

	procedure set_etag(p_etag varchar2) is
	begin
		gv_etag := p_etag;
	end;

	function get_etag return varchar2 is
	begin
		return regexp_substr(r.cgi('If-None-Match'), '^"(.*)"$', subexpression => 1);
	end;

	function str2date(p_str varchar2) return date is
	begin
		return to_date(p_str, gc_date_format, gc_date_lang) + nvl(owa_custom.dbms_server_gmtdiff, 0) / 24;
	end;

	function date2str(p_date date) return varchar2 is
	begin
		return to_char(p_date - nvl(owa_custom.dbms_server_gmtdiff, 0) / 24, gc_date_format, gc_date_lang);
	end;

	procedure set_last_modified(p_date date := sysdate) is
	begin
		gv_last_modified := p_date;
	end;

	function get_if_modified_since return date is
	begin
		return str2date(owa_util.get_cgi_env('If-Modified-Since'));
	end;

	-- expire right now by default
	procedure set_expire(p_date date := sysdate) is
	begin
		gv_expire  := p_date;
		gv_max_age := ceil((p_date - sysdate) * 24 * 60 * 60);
	end;

	procedure set_expire(p_minutes number) is
	begin
		gv_expire  := sysdate + p_minutes / 24 / 60;
		gv_max_age := p_minutes * 60;
	end;

	procedure set_max_age(p_seconds number) is
	begin
		gv_max_age := p_seconds;
		gv_expire  := sysdate + p_seconds / 24 / 60 / 60;
	end;

	procedure set_no_cache is
	begin
		gv_no_cache := true;
	end;

	function is_no_cache return boolean is
	begin
		return owa_util.get_cgi_env('Pragma') = 'no-cache';
	end;

	procedure disable is
	begin
		gv_disabled := true;
	end;

	-- type for p:page u:upload s:static
	procedure dump_cache is
	begin
		if gv_disabled then
			return;
		end if;

		if gv_no_cache then
			-- ua expire 一关，所有页面和文件expire都不起作用了
			-- out('Cache-Control: no-cache'); -- 似乎不起作用
			htp.p('Cache-Control: max-age = 0'); -- 似乎不起作用
			htp.p('Expires: ' || date2str(sysdate)); -- 只有这个才能起作用
			return;
		end if;

		if gv_expire is not null then
			htp.p('Expires: ' || date2str(gv_expire));
			htp.p('Cache-Control: max-age = ' || to_char(gv_max_age));
		end if;
		if gv_last_modified is not null then
			htp.p('Last-Modified: ' || date2str(gv_last_modified));
		end if;
		if gv_etag is not null then
			htp.p('ETag:"' || gv_etag || '"');
		end if;
	end;

end k_http;
/

