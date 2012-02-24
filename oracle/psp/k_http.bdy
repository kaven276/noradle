create or replace package body k_http is

	procedure flush is
	begin
		output.flush;
	end;

	procedure status_line(code pls_integer := 200) is
	begin
		pv.status_code := code;
	end;

	procedure sts_501_not_implemented is
	begin
		pv.status_code := 501;
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
		declare
			v_raw raw(1);
		begin
			v_raw := utl_i18n.string_to_raw('?', pv.charset_ora);
		exception
			when others then
				e.chk(true, -20001, 'other than unicode(utf-8) and db charset is not supported yet');
		end;
		pv.headers('Content-Type') := mime_type || '; charset=' || charset;
		pv.allow_content := true;
		-- r.unescape_parameters;
	end;

	procedure content_encoding_gzip is
	begin
		pv.headers('Content-Encoding') := 'gzip';
		pv.gzip := true;
	end;

	procedure content_encoding_identity is
	begin
		pv.headers('Content-Encoding') := 'identity';
		pv.gzip := false;
	end;

	procedure content_encoding_auto is
	begin
		pv.headers.delete('Content-Encoding');
		pv.gzip := null;
	end;

	procedure location(url varchar2) is
	begin
		-- [todo] absolute URI
		pv.headers('Location') := utl_url.escape(url, false, pv.charset_ora);
	end;

	procedure transfer_encoding_chunked is
	begin
		e.chk(r.type = 'c', -20008, '_c can not use chunked encoding');
		pv.headers('Transfer-Encoding') := 'chunked';
		pv.use_stream := true;
	end;

	procedure transfer_encoding_identity is
	begin
		pv.headers('Transfer-Encoding') := 'identity';
		pv.use_stream := false;
	end;

	procedure transfer_encoding_auto is
	begin
		pv.headers.delete('Transfer-Encoding');
		pv.use_stream := false; -- default to not use_stream
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

	procedure write_head is
		v  varchar2(4000);
		nl varchar2(2) := chr(13) || chr(10);
		l  pls_integer;
		n  varchar2(30);
		c  varchar2(4000);
	begin
		if pv.header_writen then
			return;
		else
			pv.header_writen := true;
		end if;
	
		begin
			if pv.headers('Transfer-Encoding') = 'chunked' then
				pv.headers.delete('Content-Length');
			end if;
		exception
			when no_data_found then
				null;
		end;
	
		v := pv.status_code || nl || 'Date: ' || t.hdt2s(sysdate) || nl;
		n := pv.headers.first;
		while n is not null loop
			v := v || n || ': ' || pv.headers(n) || nl;
			n := pv.headers.next(n);
		end loop;
		n := pv.cookies.first;
		while n is not null loop
			v := v || pv.cookies(n) || nl;
			n := pv.cookies.next(n);
		end loop;
		l := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
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
		pv.etag_md5 := true;
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
		pv.content_md5 := true;
	end;

	procedure content_md5_off is
	begin
		pv.content_md5 := false;
	end;

	procedure content_md5_auto is
	begin
		pv.content_md5 := null;
	end;

	procedure header_close is
	begin
		pv.buffered_length := 0;
	
		if pv.allow is null then
			pv.allow := case r.type
										when 'b' then
										 'GET'
										when 'c' then
										 'POST'
										else
										 'GET,POST'
									end;
		end if;
	
		if pv.allow is not null and instr(',' || pv.allow || ',', r.method) <= 0 then
			h.status_line(405); -- Method Not Allowed
			pv.headers('Allow') := pv.allow;
			if pv.use_stream then
				write_head;
			end if;
			raise pv.ex_resp_done;
		end if;
	
		if pv.use_stream then
			e.chk(pv.use_stream and pv.gzip, -20006, 'when use stream/chunked transfer, gzip are not supported');
			-- stream and gzip is impossible, utl_compress will forbid other lob operation until close
			-- gzip parts can be add progressively, but cannot output progressively
			write_head;
		end if;
	
		if r.lmt = pv.max_lmt then
			h.status_line(304);
			raise pv.ex_resp_done;
		end if;
	end;

	procedure go
	(
		url    varchar2,
		status number := null -- maybe 302(_b),303(_c feedback),201(_c new)
	) is
	begin
		status_line(nvl(status, case r.type when 'c' then 303 else 302 end));
		location(url);
		pv.headers('Content-Length') := '0';
		write_head;
		utl_tcp.flush(pv.c);
		pv.buffered_length := 0;
		pv.allow_content   := false;
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
		write_head;
		pv.buffered_length := 0;
		pv.allow_content   := false;
	end;

	procedure www_authenticate_digest(realm varchar2) is
	begin
		null;
	end;

	procedure allow_get is
	begin
		if r.method != 'GET' then
			pv.allow := 'GET';
			h.header_close;
		end if;
	end;

	procedure allow_post is
	begin
		if r.method != 'POST' then
			pv.allow := 'POST';
			h.header_close;
		end if;
	end;

	procedure allow(methods varchar2) is
	begin
		pv.allow := methods;
		if instrb(',' || methods || ',', r.method) <= 0 then
			h.header_close;
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
