create or replace package body k_http is

	procedure force_stream is
	begin
		pv.use_stream := true;
		-- cancel all settings that prevent stream
		pv.csslink := null;
		h.etag_md5_off;
		h.content_md5_off;
		h.content_encoding_identity;
	end;

	procedure flush is
	begin
		pv.accum_cnt := 0;
		output.flush;
	end;

	function inc_buf_cnt return pls_integer is
	begin
		pv.accum_cnt := pv.accum_cnt + 1;
		return pv.accum_cnt;
	end;

	procedure use_bom(value varchar2) is
	begin
		pv.bom := replace(value, ' ', '');
	end;

	-- public
	procedure write_raw(data in out nocopy raw) is
		v_len pls_integer;
	begin
		v_len := utl_raw.length(data);
		if data is null or v_len = 0 then
			return;
		end if;
	
		if not pv.use_stream then
			output.line(utl_raw.cast_to_nvarchar2(data), '');
		else
			pv.wlen := utl_tcp.write_raw(pv.c, data);
		end if;
	end;

	procedure write(text varchar2 character set any_cs) is
	begin
		output.line(text, '');
	end;

	procedure writeln(text varchar2 character set any_cs := '') is
	begin
		output.line(text, pv.nlbr);
	end;

	procedure string(text varchar2 character set any_cs) is
	begin
		output.line(text, '');
	end;

	procedure line(text varchar2 character set any_cs := '') is
	begin
		output.line(text, pv.nlbr);
	end;

	procedure set_line_break(nlbr varchar2) is
	begin
		pv.nlbr := nlbr;
	end;

	procedure save_pointer is
	begin
		pv.pg_svptr := pv.pg_len + lengthb(pv.pg_buf);
	end;

	function appended return boolean is
	begin
		return pv.pg_svptr = pv.pg_len + lengthb(pv.pg_buf);
	end;

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
		e.chk(lower(name) in ('content-type', 'content-encoding', 'content-length', 'transfer-encoding'),
					-20004,
					'You must use the specific API instead of the general h.header API to set the http header field');
		pv.headers(name) := value;
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

	procedure location(url varchar2) is
	begin
		-- [todo] absolute URI
		pv.headers('Location') := utl_url.escape(url, false, pv.charset_ora);
	end;

	procedure content_disposition_attachment(filename varchar2) is
	begin
		pv.headers('Content-disposition') := 'attachment; filename=' || filename;
	end;

	procedure content_disposition_inline(filename varchar2) is
	begin
		pv.headers('Content-disposition') := 'inline; filename=' || filename;
	end;

	procedure content_language(langs varchar2) is
	begin
		pv.headers('Content-Language') := langs;
	end;

	procedure content_language_none is
	begin
		pv.headers.delete('Content-Language');
	end;

	procedure refresh
	(
		seconds number,
		url     varchar2 := null
	) is
	begin
		pv.headers('Refresh') := to_char(seconds) || t.nvl2(url, ';url=' || u(url));
	end;

	procedure expires(expt date) is
	begin
		pv.headers('Expires') := t.hdt2s(expt);
	end;

	procedure expires_now is
	begin
		pv.headers('Expires') := t.hdt2s(sysdate);
	end;

	procedure last_modified(lmt date) is
	begin
		if pv.max_lmt is null or pv.max_lmt < lmt then
			pv.max_lmt := lmt;
		end if;
		pv.headers('Last-Modified') := t.hdt2s(pv.max_lmt);
	end;

	procedure etag(etag varchar2) is
	begin
		pv.headers('ETag') := '"' || etag || '"';
	end;

	procedure etag_md5_on is
	begin
		if output.prevent_flush('h.etag_md5_on') then
			pv.etag_md5 := true;
		end if;
	end;

	procedure etag_md5_off is
	begin
		pv.etag_md5 := false;
	end;

	procedure etag_md5_auto is
	begin
		pv.etag_md5 := null;
	end;

	procedure content_md5_on is
	begin
		pv.headers('Content-MD5') := '?';
		pv.content_md5 := true;
	end;

	procedure content_md5_off is
	begin
		pv.headers.delete('Content-MD5');
		pv.content_md5 := false;
	end;

	procedure content_md5_auto is
	begin
		pv.content_md5 := null;
	end;

	procedure check_if_not_modified_since is
	begin
		if r.lmt = pv.max_lmt then
			h.status_line(304);
			output."_init"(80526);
			raise pv.ex_resp_done;
		end if;
	end;

	procedure header_close is
	begin
		check_if_not_modified_since;
	end;

	procedure go
	(
		url    varchar2,
		status number := null -- maybe 302(_b),303(_c feedback),201(_c new)
	) is
	begin
		status_line(nvl(status, case r.type when 'c' then 303 else 302 end));
		location(u(url));
		pv.headers.delete('Content-Type');
		pv.headers('Content-Length') := '0';
		output."_init"(80526);
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

	procedure return_405_not_allow is
	begin
		h.status_line(405); -- Method Not Allowed
		pv.headers('Allow') := pv.allow;
		output."_init"(80526);
		h.line('http method "' || r.method || '" are not allowed, accept "' || pv.allow || ' "only');
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
		name    in varchar2,
		value   in varchar2,
		expires in date default null,
		path    in varchar2 default null,
		domain  in varchar2 default null,
		secure  in boolean default false
	) is
		v_str varchar2(1000);
	begin
		v_str := v_str || t.tf(secure, ';secure');
		v_str := v_str || t.nvl2(domain, ';Domain=' || domain);
		v_str := v_str || t.nvl2(path, ';path=' || path);
		v_str := v_str || t.nvl2(expires, ';expires=' || t.hdt2s(expires));
		pv.cookies(name) := 'Set-Cookie: ' || name || '=' || value || v_str;
	end;

end k_http;
/
