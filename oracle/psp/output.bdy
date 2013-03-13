create or replace package body output is

	procedure "_init"(passport pls_integer) is
	begin
		if passport != 80526 then
			raise_application_error(-20000, 'can not call psp.web''s internal method');
		end if;
		pv.feedback        := false;
		pv.buffered_length := 0;
		pv.css_len         := 0;
		pv.css_ins         := null;
		pv.flushed         := false;
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
			h.header_close;
		end if;
	
		begin
			if pv.use_stream then
				pv.headers.delete('Content-Length');
				pv.headers('Transfer-Encoding') := 'chunked';
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

	procedure css(str varchar2) is
		v_out raw(32767);
		v_len pls_integer;
	begin
		v_out := utl_i18n.string_to_raw(str, pv.charset_ora);
		v_len := utl_raw.length(v_out);
	
		dbms_lob.write(pv.csstext, v_len, pv.css_len + 1, v_out);
		pv.css_len := pv.css_len + v_len;
	end;

	procedure do_css_write is
		v_raw  raw(32767);
		v_wlen number(8);
		v_pos  number := 0;
	begin
		declare
			v  varchar2(4000);
			nl varchar2(2) := chr(13) || chr(10);
			l  pls_integer;
		begin
			-- write fixed head
			v := '200' || nl || 'Date: ' || t.hdt2s(sysdate) || nl;
			v := v || 'Content-Length: ' || pv.css_len || nl;
			v := v || 'Content-Type: text/css' || nl;
			v := v || 'ETag: "' || pv.headers('x-css-md5') || '"' || nl;
			l := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
		end;
	
		for i in 1 .. ceil(pv.css_len / pv.write_buff_size) loop
			if v_pos + pv.write_buff_size > pv.css_len then
				v_wlen := pv.css_len - v_pos;
			else
				v_wlen := pv.write_buff_size;
			end if;
			dbms_lob.read(pv.csstext, v_wlen, v_pos + 1, v_raw);
			v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
			v_pos  := v_pos + v_wlen;
		end loop;
	end;

	procedure flush is
		v_raw  raw(32767);
		v_wlen number(8);
		v_pos  number := 0;
	begin
		if not pv.use_stream then
			return;
		end if;
		if not pv.header_writen then
			pv.headers('Transfer-Encoding') := 'chunked';
			write_head;
		end if;
		for i in 1 .. ceil(pv.buffered_length / pv.write_buff_size) loop
			if v_pos + pv.write_buff_size > pv.buffered_length then
				v_wlen := pv.buffered_length - v_pos;
			else
				v_wlen := pv.write_buff_size;
			end if;
			dbms_lob.read(pv.entity, v_wlen, v_pos + 1, v_raw);
			v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
			v_pos  := v_pos + v_wlen;
		end loop;
		pv.buffered_length := 0;
		pv.last_flush      := systimestamp;
		pv.flushed         := true;
	end;

	procedure write_raw(content in out nocopy raw) is
		v_len pls_integer := utl_raw.length(content);
	begin
	
		if true then
			dbms_lob.write(pv.entity, v_len, pv.buffered_length + 1, content);
			pv.buffered_length := pv.buffered_length + v_len;
		end if;
	
	end;

	procedure write(content varchar2 character set any_cs) is
	begin
		null;
	end;

	procedure write(content in out nocopy blob) is
	begin
		null;
	end;

	procedure write(content in out nocopy clob character set any_cs) is
	begin
		null;
	end;

	-- public
	procedure line
	(
		str    varchar2 character set any_cs,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	) is
		dummy pls_integer;
		v_out raw(32767);
		v_len pls_integer;
		v_str varchar2(32767);
		v_cs  varchar2(30) := pv.charset_ora;
	begin
		if str is null and nl is null then
			return;
		end if;
	
		if not pv.allow_content then
			raise_application_error(-20001, 'Content-Type not set in http header, but want to write http body');
		end if;
	
		v_len := lengthb(str);
		if v_len = length(str) then
			v_cs := null;
		else
			v_str := str;
			if v_len = lengthb(v_str) then
				-- is database charset
				if pv.charset_ora = pv.cs_char then
					v_cs := null;
				end if;
			else
				-- is national charset
				if pv.charset_ora like '%' || pv.cs_nchar then
					v_cs := null;
				end if;
			end if;
		end if;
	
		v_out := utl_i18n.string_to_raw(lpad(' ', indent, ' ') || str || nl, v_cs);
		write_raw(v_out);
	
	end;

	-- Refactored procedure do_write 
	procedure do_write(v_len in integer) is
		v_raw  raw(32767);
		v_wlen number(8);
		v_pos  number := 0;
	begin
	
		if pv.csslink = false and pv.css_len > 0 then
			v_wlen := pv.css_ins;
			dbms_lob.read(pv.entity, pv.css_ins, 1, v_raw);
			v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
		
			v_wlen := pv.css_len;
			dbms_lob.read(pv.csstext, v_wlen, 1, v_raw);
			v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
		
			v_pos := pv.css_ins;
			for i in 1 .. ceil((v_len - pv.css_ins) / 32767) loop
				v_wlen := t.tf(v_pos + 32767 > v_len, v_len - v_pos, 32767);
				dbms_lob.read(pv.entity, v_wlen, v_pos + 1, v_raw);
				v_pos  := v_pos + v_wlen;
				v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
			end loop;
			return;
		end if;
	
		for i in 1 .. ceil(v_len / pv.write_buff_size) loop
			if v_pos + pv.write_buff_size > v_len then
				v_wlen := v_len - v_pos;
			else
				v_wlen := pv.write_buff_size;
			end if;
			dbms_lob.read(pv.entity, v_wlen, v_pos + 1, v_raw);
			v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
			v_pos  := v_pos + v_wlen;
		end loop;
	end do_write;

	procedure finish is
		v_len  integer := pv.buffered_length;
		v_len2 integer := 0;
		v_raw  raw(32767);
		v_md5  varchar2(32);
	begin
		-- if use stream, flush the final buffered content and the end marker out
		if pv.flushed then
			line(pv.end_marker, '');
			flush;
			return;
		end if;
	
		if v_len = 0 then
			if r.type = 'c' and pv.status_code = 200 then
				-- when no content, just return back to previous page;
				if r.header('referer') is not null then
					h.go(r.header('referer'));
				else
					h.line('<script>history.back();</script>');
					v_len := pv.buffered_length;
				end if;
			end if;
			goto print_http_headers;
		elsif pv.feedback or (r.type = 'c' and pv.status_code = 200 and pv.ct_marker != 'feedback') then
			-- have content, but have feedback indication or _c
			declare
				v  varchar2(4000);
				nl varchar2(2) := chr(13) || chr(10);
				l  pls_integer;
				n  varchar2(30);
				e  pv.str_arr;
			begin
				-- write fixed head
				v := '303' || nl || 'Date: ' || t.hdt2s(sysdate) || nl;
				v := v || 'Content-Length: 0' || nl;
				v := v || 'Location: feedback?id=' || nl;
				v := v || 'Cache-Control: no-cache' || nl;
				n := pv.cookies.first;
				while n is not null loop
					v := v || pv.cookies(n) || nl;
					n := pv.cookies.next(n);
				end loop;
				pv.cookies := e;
				l          := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
			end;
			-- return;
		end if;
	
		if pv.csslink is not null and p.gv_xhtp then
			if pv.css_len > 0 then
				if pv.csslink then
					-- compute md5 digest and replace css/xxx54
					dbms_lob.trim(pv.csstext, pv.css_len);
					v_md5 := rawtohex(dbms_crypto.hash(pv.csstext, dbms_crypto.hash_md5));
					v_raw := utl_i18n.string_to_raw(v_md5, pv.charset_ora);
					dbms_lob.write(pv.entity, 32, pv.css_hld_pos + 50, v_raw);
					pv.headers('x-css-md5') := v_md5;
				else
					-- fragment_insert will not work, it's for secure lob only
					v_len2 := pv.css_len;
				end if;
			else
				-- remove placeholder
				v_raw := utl_i18n.string_to_raw(lpad(chr(10), pv.css_hld_len, ' '), pv.charset_ora);
				dbms_lob.write(pv.entity, pv.css_hld_len, pv.css_hld_pos + 1, v_raw);
			end if;
		end if;
	
		-- zip is for streamed output, it's conflict with content_md5 computation
		if pv.content_md5 and pv.headers('Content-Encoding') in ('try', '?') then
			pv.content_md5 := false;
		end if;
	
		if pv.content_md5 or pv.etag_md5 then
			dbms_lob.trim(pv.entity, v_len);
			v_raw := dbms_crypto.hash(pv.entity, dbms_crypto.hash_md5);
			v_md5 := utl_raw.cast_to_varchar2(utl_encode.base64_encode(v_raw));
			if pv.content_md5 then
				pv.headers('Content-MD5') := v_md5;
			end if;
			if pv.etag_md5 then
				if r.etag = v_md5 then
					h.status_line(304);
					v_len  := 0;
					v_len2 := 0;
				else
					h.etag(v_md5);
				end if;
			end if;
		end if;
	
		<<print_http_headers>>
		pv.headers('Content-Length') := to_char(v_len + v_len2);
		pv.headers('x-pw-elapsed-time') := to_char((dbms_utility.get_time - pv.elpt) * 10) || ' ms';
		pv.headers('x-pw-cpu-time') := to_char((dbms_utility.get_cpu_time - pv.cput) * 10) || ' ms';
	
		pv.use_stream := false;
		write_head;
		if pv.etag_md5 then
			if utl_tcp.get_line(pv.c, true) = 'Cache Hit' then
				return;
			end if;
		end if;
		do_write(v_len);
		if pv.csslink and pv.css_len > 0 then
			do_css_write;
		end if;
	end;

end output;
/
