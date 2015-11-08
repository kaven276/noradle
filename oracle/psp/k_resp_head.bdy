create or replace package body k_resp_head is

	procedure status_line(code pls_integer := 200) is
	begin
		pv.status_code := code;
	end;

	procedure sts_200_ok is
	begin
		pv.status_code := 200;
	end;

	procedure sts_300_multiple_choices is
	begin
		pv.status_code := 300;
	end;

	procedure sts_301_moved_permanently is
	begin
		pv.status_code := 301;
	end;

	procedure sts_302_found is
	begin
		pv.status_code := 302;
	end;

	procedure sts_303_see_other is
	begin
		pv.status_code := 303;
	end;

	procedure sts_304_not_modified is
	begin
		pv.status_code := 304;
	end;

	procedure sts_307_temporary_redirect is
	begin
		pv.status_code := 307;
	end;

	procedure sts_403_forbidden is
	begin
		pv.status_code := 403;
	end;

	procedure sts_404_not_found is
	begin
		pv.status_code := 404;
	end;

	procedure sts_406_not_acceptable is
	begin
		pv.status_code := 406;
	end;

	procedure sts_409_conflict is
	begin
		pv.status_code := 409;
	end;

	procedure sts_410_gone is
	begin
		pv.status_code := 410;
	end;

	procedure sts_500_internal_server_error is
	begin
		pv.status_code := 500;
	end;

	procedure sts_501_not_implemented is
	begin
		pv.status_code := 501;
	end;

	procedure sts_503_service_unavailable is
	begin
		pv.status_code := 503;
	end;

	procedure header
	(
		name  varchar2,
		value varchar2
	) is
	begin
		e.chk(false and lower(name) in ('content-type', 'content-encoding', 'content-length', 'transfer-encoding'),
					-20004,
					'You must use the specific API instead of the general h.header API to set the http header field');
		if pv.pg_idxsp is null then
			pv.headers(name) := value;
		else
			pv.mp_headers(name) := value;
		end if;
	end;

	function header(name varchar2) return varchar2 is
	begin
		return pv.headers(name);
	exception
		when no_data_found then
			return '';
	end;

	procedure use_bom(value varchar2) is
	begin
		pv.bom := replace(value, ' ', '');
	end;

	procedure content_type
	(
		mime_type varchar2 := 'text/html',
		charset   varchar2 := 'UTF-8'
	) is
	begin
		e.chk(lower(charset) = 'utf8', -20002, 'IANA charset should be utf-8, not utf8');
		-- e.chk(r.type = 'c', -20005, '_c layer should not have entity content, so should not set content-type');
		pv.mime_type := mime_type;
		pv.charset   := lower(charset);
		-- utl_i18n.generic_context, utl_i18n.iana_to_oracle
		pv.charset_ora := utl_i18n.map_charset(charset, 0, 1);
		if pv.charset_ora = 'AL32UTF8' and pv.cs_nchar = 'UTF8' then
			pv.charset_ora := 'UTF8';
		end if;
		pv.pg_nchar := not (pv.charset_ora = pv.cs_char);
		pv.pg_conv  := not pv.charset_ora in (pv.cs_char, pv.cs_nchar);
		pv.cs_req   := pv.charset_ora;
		declare
			v_raw raw(6);
		begin
			v_raw := utl_i18n.string_to_raw('?', pv.charset_ora);
		exception
			when others then
				e.chk(true, -20001, 'other than unicode(utf-8) and db charset is not supported yet ' || pv.charset_ora);
		end;
		pv.headers('Content-Type') := mime_type || '; charset=' || charset;
		-- r.unescape_parameters;
	end;

	function charset return varchar2 is
	begin
		return pv.charset;
	end;

	function mime_type return varchar2 is
	begin
		return pv.mime_type;
	end;

	procedure content_language(langs varchar2) is
	begin
		pv.headers('Content-Language') := langs;
	end;

	procedure content_language_none is
	begin
		pv.headers.delete('Content-Language');
	end;

	procedure content_encoding_try_zip is
	begin
		pv.headers('Content-Encoding') := 'zip';
	end;

	procedure content_encoding_identity is
	begin
		pv.headers('Content-Encoding') := 'identity';
	end;

	procedure content_encoding_auto is
	begin
		pv.headers('Content-Encoding') := '?';
	end;

	procedure content_md5_on is
	begin
		pv.headers('Content-MD5') := '?';
	end;

	procedure content_md5_off is
	begin
		pv.headers.delete('Content-MD5');
	end;

	procedure content_md5_auto is
	begin
		null;
	end;

	procedure content_disposition_attachment(filename varchar2) is
	begin
		pv.headers('Content-Disposition') := 'attachment; filename=' || filename;
	end;

	procedure content_disposition_inline(filename varchar2) is
	begin
		pv.headers('Content-Disposition') := 'inline; filename=' || filename;
	end;

	procedure expires(expt date) is
	begin
		pv.headers('Expires') := t.hdt2s(expt);
	end;

	procedure expires_now is
	begin
		pv.headers('Expires') := t.hdt2s(sysdate);
	end;

	procedure expires_as_maxage is
		expt date := sysdate + nvl(to_number(pv.caches('max-age')), 0) / 24 / 60 / 60;
	begin
		pv.headers('Expires') := t.hdt2s(expt);
	end;

	procedure last_modified(lmt date) is
	begin
		if pv.max_lmt is null or pv.max_lmt < lmt then
			pv.max_lmt := lmt;
			pv.headers('Last-Modified') := t.hdt2s(pv.max_lmt);
		end if;
	end;

	procedure check_if_not_modified_since is
	begin
		if r.lmt = pv.max_lmt then
			h.status_line(304);
			bdy.print_init(true);
			raise pv.ex_resp_done;
		end if;
	end;

	procedure last_scn(scn number) is
	begin
		if pv.max_scn is null or pv.max_scn < scn then
			pv.max_scn := scn;
			pv.headers('ETag') := 'W/"' || pv.max_scn || '"';
		end if;
	end;

	procedure check_if_none_match_scn is
	begin
		if r.etag = 'W/"' || pv.max_scn || '"' then
			h.status_line(304);
			bdy.print_init(true);
			raise pv.ex_resp_done;
		end if;
	end;

	procedure etag(etag varchar2) is
	begin
		pv.headers('ETag') := '"' || etag || '"';
	end;

	procedure etag_md5_on is
	begin
		if pv.use_stream = true then
			raise_application_error(-20000, 'force stream found when require in-db digest');
		end if;
		pv.etag_md5   := true;
		pv.use_stream := false;
	end;

	procedure etag_md5_off is
	begin
		pv.etag_md5 := false;
	end;

	procedure etag_md5_auto is
	begin
		pv.etag_md5 := null;
	end;

	procedure header_close is
	begin
		check_if_not_modified_since;
		check_if_none_match_scn;
	end;

	procedure refresh
	(
		seconds number,
		url     varchar2 := null
	) is
	begin
		pv.headers('Refresh') := to_char(seconds) || t.nvl2(url, ';url=' || l(url));
	end;

	procedure location(url varchar2) is
	begin
		-- [todo] absolute URI
		pv.headers('Location') := utl_url.escape(l(url), false, pv.charset_ora);
	end;

	procedure redirect
	(
		url    varchar2,
		status number := null -- maybe 302(_b),303(_c feedback),201(_c new)
	) is
	begin
		status_line(nvl(status, case r.type when 'c' then 303 else 302 end));
		location(url);
	end;

	procedure go
	(
		url    varchar2,
		status number := null -- maybe 302(_b),303(_c feedback),201(_c new)
	) is
	begin
		redirect(url);
		pv.headers.delete('Content-Type');
		pv.headers('Content-Length') := '0';
		bdy.print_init(true);
		commit;
		raise pv.ex_resp_done;
	end;

	procedure retry_after(delta number) is
	begin
		pv.headers('Retry-After') := to_char(delta);
	end;

	procedure retry_after(future date) is
	begin
		pv.headers('Retry-After') := t.hdt2s(future);
	end;

	procedure www_authenticate_basic(realm varchar2) is
	begin
		status_line(401);
		pv.headers('WWW-Authenticate') := 'Basic realm="' || realm || '"';
	end;

	procedure www_authenticate_digest(realm varchar2) is
	begin
		e.raise(-20025, 'PSP.WEB have not implenment http digest authentication.');
	end;

	-- private
	procedure return_405_not_allow is
	begin
		h.status_line(405); -- Method Not Allowed
		pv.headers('Allow') := pv.allow;
		bdy.print_init(true);
		b.line('http method "' || r.method || '" are not allowed, accept "' || pv.allow || ' "only');
		raise pv.ex_resp_done;
	end;

	procedure allow_get is
	begin
		pv.allow := 'GET';
		if r.method != 'GET' then
			return_405_not_allow;
		end if;
	end;

	procedure allow_post is
	begin
		pv.allow := 'POST';
		if r.method != 'POST' then
			return_405_not_allow;
		end if;
	end;

	procedure allow_get_post is
	begin
		allow('GET,POST');
	end;

	procedure allow(methods varchar2) is
	begin
		pv.allow := methods;
		if instrb(',' || methods || ',', ',' || r.method || ',') <= 0 then
			return_405_not_allow;
		end if;
	end;

	procedure set_cookie
	(
		name     in varchar2,
		value    in varchar2,
		expires  in date default null,
		path     in varchar2 default null,
		domain   in varchar2 default null,
		secure   in boolean default false,
		httponly in boolean default true
	) is
		v_str varchar2(1000);
	begin
		v_str := v_str || t.tf(secure, ';secure');
		v_str := v_str || t.tf(httponly, ';HttpOnly', '', ';HttpOnly');
		v_str := v_str || t.nvl2(domain, ';Domain=' || domain);
		v_str := v_str || t.nvl2(path, ';path=' || path);
		v_str := v_str || t.nvl2(expires, ';expires=' || t.hdt2s(expires));
		pv.cookies(name) := name || '=' || value || v_str;
	end;

	procedure convert_json(callback varchar2 := null) is
		v_cb varchar2(4000) := nvl(callback, r.getc('callback', ''));
	begin
		if mime_type = 'text/html' then
			h.content_type('text/resultsets', 'UTF-8');
		end if;
		if v_cb is not null then
			h.header('_callback', v_cb);
			if not r.is_lack('useraw') then
				h.header('_useraw', 'Y');
			end if;
		end if;
	end;

	procedure convert_json_template
	(
		template varchar2,
		engine   varchar2 := null
	) is
	begin
		h.content_type('text/resultsets', 'UTF-8');
		h.header('_template', template);
		if engine is not null then
			h.header('_engine', engine);
		end if;
	end;

end k_resp_head;
/
