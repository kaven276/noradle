create or replace package body k_http is

	procedure status_line(code pls_integer := 200) is
	begin
		pv.status_code := code;
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
		e.chk(r.type = 'c', -20005, '_c layer should not have entity content, so should not set content-type');
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
		l := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
	end;

	procedure last_modified(lmt date) is
	begin
		pv.headers('Last-Modified') := t.hdt2s(lmt);
	end;

	procedure etag(etag varchar2) is
	begin
		pv.headers('ETag') := '"' || etag || '"';
	end;

	procedure etag_md5 is
	begin
		null;
	end;

	procedure content_md5 is
	begin
		null;
	end;

	procedure http_header_close is
	begin
		if pv.use_stream then
			write_head;
		end if;
	
		if not pv.allow_content then
			null; -- go out, cease execution
		end if;
	
		-- stream and gzip is impossible, utl_compress will forbid other lob operation until close
		-- gzip parts can be add progressively, but cannot output progressively
		e.chk(pv.use_stream and pv.gzip, -20006, 'when use stream/chunked transfer, gzip are not supported');
	
		pv.buffered_length := 0;
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
		null;
	end;

	procedure retry_after(future date) is
	begin
		null;
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

end k_http;
/
