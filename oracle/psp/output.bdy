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
		sts.stack   := '';
	end;

	-- private
	function get_buf_byte_len return pls_integer is
	begin
		if pv.pg_nchar then
			return pv.pg_len + nvl(lengthb(pv.pg_buf), 0) + nvl(lengthb(pv.bom) / 2, 0);
		else
			return pv.pg_len + nvl(lengthb(pv.ph_buf), 0) + nvl(lengthb(pv.bom) / 2, 0);
		end if;
	end;

	procedure write_head is
	begin
		if pv.header_writen then
			return;
		end if;
		pv.header_writen := true;
		if pv.bom is not null then
			pv.headers('x-pw-bom-hex') := pv.bom;
		end if;
		bios.write_head;
	end;

	procedure switch_css is
	begin
		if pv.pg_nchar then
			if pv.pg_conv then
				pv.pg_parts(pv.pg_index + 1) := convert(pv.pg_buf, pv.charset_ora, pv.cs_nchar);
			else
				pv.pg_parts(pv.pg_index + 1) := pv.pg_buf;
			end if;
			pv.pg_parts(pv.pg_index + 2) := ' ';
			pv.pg_len := pv.pg_len + lengthb(pv.pg_parts(pv.pg_index + 1)) + lengthb(n' ');
			pv.pg_buf := '';
		else
			pv.ph_parts(pv.pg_index + 1) := pv.ph_buf;
			pv.ph_parts(pv.pg_index + 2) := ' ';
			pv.pg_len := pv.pg_len + lengthb(pv.ph_buf) + lengthb(' ');
			pv.ph_buf := '';
		end if;
		pv.pg_cssno := pv.pg_index + 2;
		pv.pg_index := pv.pg_index + 2;
	end;

	procedure css(str varchar2 character set any_cs) is
	begin
		pv.pg_css := pv.pg_css || str;
	end;

	-- private, called by .flush or .finish
	procedure write_buf(p_len pls_integer := get_buf_byte_len) is
	begin
		if p_len = 0 then
			return;
		end if;
		case pv.entry
			when 'gateway.listen' then
				if pv.flushed then
					pv.wlen := utl_tcp.write_raw(pv.c, utl_raw.cast_from_binary_integer(p_len));
				end if;
			when 'framework.entry' then
				bios.wpi(pv.cslot_id * 256 * 256 + 1 * 256 + 0);
				bios.wpi(p_len);
		end case;
	
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
		chunk_init;
	end;

	procedure flush is
	begin
		if not pv.use_stream then
			return;
		end if;
		if pv.flushed = false then
			pv.flushed := true;
			pv.headers('Transfer-Encoding') := 'chunked';
		end if;
		if not pv.header_writen then
			write_head;
		end if;
		if pv.pg_conv then
			pv.pg_buf := convert(pv.pg_buf, pv.charset_ora, pv.cs_nchar);
		end if;
		write_buf;
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
	
		case pv.entry
			when 'gateway.listen' then
				pv.wlen := utl_tcp.write_raw(pv.c, utl_raw.cast_from_binary_integer(lengthb(v)));
				pv.wlen := utl_tcp.write_text(pv.c, v);
				pv.wlen := utl_tcp.write_text(pv.c, pv.pg_css);
			when 'framework.entry' then
				bios.wpi(pv.cslot_id * 256 * 256 + 3 * 256 + 0);
				bios.wpi(lengthb(pv.pg_css));
				pv.wlen := utl_tcp.write_text(pv.c, pv.pg_css);
		end case;
	end;

	procedure switch is
	begin
		pv.pg_index := pv.pg_index + 1;
		if pv.pg_nchar then
			if pv.pg_conv then
				pv.pg_parts(pv.pg_index) := convert(pv.pg_buf, pv.charset_ora, pv.cs_nchar);
			else
				pv.pg_parts(pv.pg_index) := pv.pg_buf;
			end if;
			pv.pg_len := pv.pg_len + lengthb(pv.pg_parts(pv.pg_index));
		else
			pv.ph_parts(pv.pg_index) := pv.ph_buf;
			pv.pg_len := pv.pg_len + lengthb(pv.ph_buf);
		end if;
	end;

	procedure line
	(
		str    varchar2 character set any_cs,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	) is
	begin
		if pv.pg_nchar then
			pv.pg_buf := pv.pg_buf || (lpad(n' ', indent, ' ') || str || nl);
		else
			pv.ph_buf := pv.ph_buf || (lpad(' ', indent, ' ') || str || nl);
		end if;
	exception
		when others then
			-- 6502 numeric or value error: character string buffer too small
			if pv.use_stream then
				flush;
			else
				switch;
			end if;
			if pv.pg_nchar then
				pv.pg_buf := lpad(' ', indent, ' ') || str || nl;
			else
				pv.ph_buf := lpad(' ', indent, ' ') || str || nl;
			end if;
	end;

	procedure finish is
		v_len integer;
		v_raw raw(32767);
		v_md5 varchar2(32);
		v_tmp nvarchar2(32767);
		v_lob nclob;
	begin
		-- if use stream, flush the final buffered content and the end marker out
		if pv.flushed then
			flush;
			return;
		end if;
	
		if pv.pg_conv then
			pv.pg_buf := convert(pv.pg_buf, pv.charset_ora, pv.cs_nchar);
		end if;
		v_len := get_buf_byte_len;
	
		if v_len = 0 then
			goto print_http_headers;
		end if;
	
		if pv.pg_css is not null and pv.csslink is not null then
			-- use pv.csslink will set pv.pg_css to '', and allow css write
			-- so if pv.pg_css is not null,
			case pv.csslink
				when true then
					if pv.charset_ora != pv.cs_nchar then
						pv.pg_css := convert(pv.pg_css, pv.charset_ora, pv.cs_nchar);
					end if;
					v_md5 := rawtohex(dbms_crypto.hash(utl_raw.cast_to_raw(pv.pg_css), dbms_crypto.hash_md5));
					pv.headers('x-css-md5') := v_md5;
					v_tmp := '<link type="text/css" rel="stylesheet" href="css_b/' || v_md5 || '"/>';
				when false then
					v_tmp := n'<style>' || pv.pg_css || n'</style>';
				else
					null;
			end case;
			if pv.pg_nchar then
				if pv.charset_ora = pv.cs_nchar then
					pv.pg_parts(pv.pg_cssno) := v_tmp;
				else
					pv.pg_parts(pv.pg_cssno) := convert(v_tmp, pv.charset_ora, pv.cs_nchar);
				end if;
				v_len := v_len + lengthb(pv.pg_parts(pv.pg_cssno)) - lengthb(n' ');
			else
				pv.ph_parts(pv.pg_cssno) := to_char(v_tmp);
				v_len := v_len + lengthb(pv.ph_parts(pv.pg_cssno)) - lengthb(' ');
			end if;
		
		end if;
	
		-- zip is for streamed output, it's conflict with content_md5 computation
		if pv.content_md5 and pv.headers('Content-Encoding') in ('try', '?') then
			pv.content_md5 := false;
		end if;
	
		if (pv.content_md5 or pv.etag_md5) and pv.pg_nchar and pv.status_code = 200 then
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
	
		pv.headers('Content-Length') := to_char(v_len);
		if v_len = 0 then
			pv.headers.delete('Content-Type');
			pv.headers.delete('Content-Encoding');
		end if;
		write_head;
		write_buf(v_len);
		if pv.etag_md5 then
			if utl_tcp.get_line(pv.c, true) = 'Cache Hit' then
				return;
			end if;
		end if;
	
		if pv.csslink = true and pv.pg_css is not null then
			do_css_write;
		end if;
	
	end;

end output;
/
