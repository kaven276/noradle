create or replace package body output is

	-- private
	procedure chunk_init is
	begin
		pv.pg_buf   := '';
		pv.ph_buf   := '';
		pv.pg_index := 0;
		pv.pg_len   := 0;
		pv.pg_parts.delete;
		pv.ph_parts.delete;
	end;

	procedure "_init"(passport pls_integer) is
	begin
		if passport != 80526 then
			raise_application_error(-20000, 'can not call psp.web''s internal method');
		end if;
		chunk_init;
		pv.pg_css   := '';
		pv.pg_cssno := null;
		pv.flushed  := false;
		p.gv_xhtp   := false;
	end;

	-- private
	function get_len return pls_integer is
	begin
		if pv.pg_nchar then
			return pv.pg_len + nvl(lengthb(pv.pg_buf), 0) + nvl(lengthb(pv.bom) / 2, 0);
		else
			return pv.pg_len + nvl(lengthb(pv.ph_buf), 0) + nvl(lengthb(pv.bom) / 2, 0);
		end if;
	end;

	procedure write_head is
		v  varchar2(4000);
		nl varchar2(2) := chr(13) || chr(10);
		n  varchar2(30);
	begin
		if pv.header_writen then
			return;
		end if;
		pv.header_writen := true;
	
		if pv.bom is not null then
			pv.headers('x-pw-bom-hex') := pv.bom;
		end if;
		pv.headers('x-pw-ori-len') := to_char(get_len);
	
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
		pv.wlen := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
		pv.wlen := utl_tcp.write_raw(pv.c, hextoraw(pv.bom));
	end;

	procedure switch_css is
	begin
		if pv.pg_nchar then
			pv.pg_parts(pv.pg_index + 1) := pv.pg_buf;
			pv.pg_parts(pv.pg_index + 2) := ' ';
			pv.pg_len := pv.pg_len + lengthb(pv.pg_buf) + 1;
			pv.pg_buf := '';
		else
			pv.ph_parts(pv.pg_index + 1) := pv.ph_buf;
			pv.ph_parts(pv.pg_index + 2) := ' ';
			pv.pg_len := pv.pg_len + lengthb(pv.ph_buf) + 1;
			pv.ph_buf := '';
		end if;
		pv.pg_cssno := pv.pg_index + 2;
		pv.pg_index := pv.pg_index + 2;
	end;

	procedure css(str varchar2) is
	begin
		pv.pg_css := pv.pg_css || str;
	end;

	function prevent_flush(text varchar2) return boolean is
	begin
		if pv.flushed then
			k_debug.trace(st('prevent flush ignored', text, r.dbu, r.prog));
			return false;
		else
			pv.use_stream := false;
			return true;
		end if;
	end;

	-- private
	procedure write_buf(p_len pls_integer := get_len) is
	begin
		if p_len = 0 then
			return;
		end if;
		if not pv.pg_conv then
			if pv.pg_nchar then
				for i in 1 .. pv.pg_index loop
					pv.wlen := utl_tcp.write_text(pv.c, pv.pg_parts(i));
				end loop;
				pv.wlen := utl_tcp.write_text(pv.c, pv.pg_buf);
			else
				for i in 1 .. pv.pg_index loop
					pv.wlen := utl_tcp.write_text(pv.c, pv.ph_parts(i));
				end loop;
				pv.wlen := utl_tcp.write_text(pv.c, pv.ph_buf);
			end if;
		else
			if pv.pg_nchar then
				for i in 1 .. pv.pg_index loop
					pv.wlen := utl_tcp.write_text(pv.c, convert(pv.pg_parts(i), pv.charset_ora, pv.cs_nchar));
				end loop;
				pv.wlen := utl_tcp.write_text(pv.c, convert(pv.pg_buf, pv.charset_ora, pv.cs_nchar));
			else
				for i in 1 .. pv.pg_index loop
					pv.wlen := utl_tcp.write_text(pv.c, convert(pv.ph_parts(i), pv.charset_ora, pv.cs_nchar));
				end loop;
				pv.wlen := utl_tcp.write_text(pv.c, convert(pv.ph_buf, pv.charset_ora, pv.cs_nchar));
			end if;
		end if;
		chunk_init;
	end;

	procedure flush is
	begin
		if not pv.use_stream then
			return;
		end if;
		if not pv.header_writen then
			pv.headers('Transfer-Encoding') := 'chunked';
			write_head;
		end if;
		write_buf;
		pv.flushed := true;
	end;

	procedure do_css_write is
		v  varchar2(4000);
		nl varchar2(2) := chr(13) || chr(10);
	begin
		-- get fixed head
		v := '200' || nl || 'Date: ' || t.hdt2s(sysdate) || nl;
		v := v || 'Content-Length: ' || lengthb(pv.pg_css) || nl;
		v := v || 'Content-Type: text/css' || nl;
		v := v || 'ETag: "' || pv.headers('x-css-md5') || '"' || nl;
	
		pv.wlen := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
		pv.wlen := utl_tcp.write_text(pv.c, pv.pg_css);
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

	procedure line
	(
		str    varchar2 character set any_cs,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	) is
	begin
		if pv.pg_nchar then
			pv.pg_buf := pv.pg_buf || (lpad(' ', indent, ' ') || str || nl);
		else
			pv.ph_buf := pv.ph_buf || (lpad(' ', indent, ' ') || str || nl);
		end if;
	exception
		when others then
			-- 6502 numeric or value error: character string buffer too small
			if pv.use_stream then
				flush;
			else
				pv.pg_index := pv.pg_index + 1;
				if pv.pg_nchar then
					pv.pg_parts(pv.pg_index) := pv.pg_buf;
					pv.pg_len := pv.pg_len + lengthb(pv.pg_buf);
				else
					pv.ph_parts(pv.pg_index) := pv.ph_buf;
					pv.pg_len := pv.pg_len + lengthb(pv.ph_buf);
				end if;
			end if;
			if pv.pg_nchar then
				pv.pg_buf := lpad(' ', indent, ' ') || str || nl;
			else
				pv.ph_buf := lpad(' ', indent, ' ') || str || nl;
			end if;
	end;

	procedure finish is
		v_len integer := get_len;
		v_raw raw(32767);
		v_md5 varchar2(32);
		v_tmp nvarchar2(32767);
		v_lob nclob;
	begin
		-- if use stream, flush the final buffered content and the end marker out
		if pv.flushed then
			line(pv.end_marker, '');
			flush;
			return;
		end if;
	
		if v_len = 0 then
			if r.type = 'c' and pv.status_code = 200 then
				-- for _c, if no content, just return back to previous page;
				if r.header('referer') is not null then
					h.go(r.header('referer'));
				else
					h.content_type;
					h.line('<script>history.back();</script>');
					v_len := get_len;
				end if;
			end if;
			goto print_http_headers;
		elsif pv.feedback or (pv.feedback is null and r.type = 'c' and pv.status_code = 200) then
			-- have content, but have feedback indication or _c sts=200
			declare
				v  varchar2(4000);
				nl varchar2(2) := chr(13) || chr(10);
				n  varchar2(30);
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
				pv.cookies.delete;
				pv.wlen := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
			end;
			-- after above, write feedback page
		end if;
	
		if pv.pg_css is not null and p.gv_xhtp and pv.csslink is not null then
			-- use pv.csslink will set pv.pg_css to '', and allow css write
			-- so if pv.pg_css is not null,
			case pv.csslink
				when true then
					v_md5 := rawtohex(dbms_crypto.hash(utl_raw.cast_to_raw(pv.pg_css), dbms_crypto.hash_md5));
					pv.headers('x-css-md5') := v_md5;
					v_tmp := '<link type="text/css" rel="stylesheet" href="css/' || v_md5 || '"/>';
				when false then
					v_tmp := '<style>' || pv.pg_css || '</style>';
				else
					null;
			end case;
			if pv.pg_nchar then
				pv.pg_parts(pv.pg_cssno) := v_tmp;
				v_len := v_len + lengthb(v_tmp) - 1;
			else
				pv.ph_parts(pv.pg_cssno) := to_char(v_tmp);
				v_len := v_len + lengthb(pv.ph_parts(pv.pg_cssno)) - 1;
			end if;
		
		end if;
	
		-- zip is for streamed output, it's conflict with content_md5 computation
		if pv.content_md5 and pv.headers('Content-Encoding') in ('try', '?') then
			pv.content_md5 := false;
		end if;
	
		if (pv.content_md5 or pv.etag_md5) and pv.pg_nchar then
			dbms_lob.createtemporary(v_lob, true, dur => dbms_lob.call);
			for i in 1 .. pv.pg_index loop
				dbms_lob.writeappend(v_lob, length(pv.pg_parts(i)), pv.pg_parts(i));
			end loop;
			dbms_lob.writeappend(v_lob, length(pv.pg_buf), pv.pg_buf);
			v_raw := dbms_crypto.hash(v_lob, dbms_crypto.hash_md5);
			v_md5 := utl_raw.cast_to_varchar2(utl_encode.base64_encode(v_raw));
			if pv.content_md5 then
				pv.headers('Content-MD5') := v_md5;
			end if;
			if pv.etag_md5 then
				if r.etag = v_md5 then
					h.status_line(304);
					v_len := 0;
				else
					h.etag(v_md5);
				end if;
			end if;
		end if;
	
		<<print_http_headers>>
	
		$if k_ccflag.use_time_stats $then
		declare
			v1 number(10) := dbms_utility.get_time;
			v2 number(10) := dbms_utility.get_cpu_time;
		begin
			pv.headers('x-pw-timespan') := ((v1 - pv.elpt) * 10) || ' / ' || ((v2 - pv.cput) * 10) || ' ms';
		end;
		$end
	
		if not pv.pg_conv then
			pv.headers('Content-Length') := to_char(v_len);
			write_head;
			write_buf(v_len);
			if pv.etag_md5 then
				if utl_tcp.get_line(pv.c, true) = 'Cache Hit' then
					return;
				end if;
			end if;
		else
			write_head;
			write_buf(v_len);
			pv.wlen := utl_tcp.write_text(pv.c, pv.end_marker);
		end if;
	
		if pv.csslink = true and pv.pg_css is not null then
			do_css_write;
		end if;
	
	end;

end output;
/
