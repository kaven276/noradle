create or replace package body output is

	procedure "_init"(passport pls_integer) is
	begin
		if passport != 80526 then
			raise_application_error(-20000, 'can not call psp.web''s internal method');
		end if;
		pv.buffered_length := 0;
		pv.css_len         := 0;
		pv.css_ins         := null;
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
			v := v || 'ETag:"' || 'cssmd5"' || nl;
			l := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
			utl_tcp.flush(pv.c);
		end;
	
		for i in 1 .. ceil(pv.css_len / pv.write_buff_size) loop
			if v_pos + pv.write_buff_size > pv.css_len then
				v_wlen := pv.css_len - v_pos;
			else
				v_wlen := pv.write_buff_size;
			end if;
			dbms_lob.read(pv.csstext, v_wlen, v_pos + 1, v_raw);
			v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
			utl_tcp.flush(pv.c);
			v_pos := v_pos + v_wlen;
		end loop;
	end;

	-- public
	procedure line
	(
		str    varchar2,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	) is
		dummy pls_integer;
		v_out raw(32767);
		v_len pls_integer;
	begin
		if str is null then
			return;
		end if;
	
		if not pv.allow_content then
			raise_application_error(-20001, 'Content-Type not set in http header, but want to write http body');
		end if;
	
		v_out := utl_i18n.string_to_raw(lpad(' ', indent, ' ') || str || nl, pv.charset_ora);
		v_len := utl_raw.length(v_out);
	
		if not pv.use_stream then
			dbms_lob.write(pv.entity, v_len, pv.buffered_length + 1, v_out);
			pv.buffered_length := pv.buffered_length + v_len;
			return;
		end if;
	
		if pv.buffered_length + v_len > pv.write_buff_size then
			utl_tcp.flush(pv.c);
			pv.buffered_length := 0;
		end if;
		dummy              := utl_tcp.write_raw(pv.c, v_out);
		pv.buffered_length := pv.buffered_length + v_len;
	end;

	procedure flush is
	begin
		if pv.use_stream then
			utl_tcp.flush(pv.c);
		end if;
	end;

	-- Refactored procedure do_write 
	procedure do_write
	(
		v_len  in integer,
		v_gzip in boolean
	) is
		v_raw  raw(32767);
		v_wlen number(8);
		v_pos  number := 0;
	begin
		h.write_head;
		utl_tcp.flush(pv.c);
	
		if v_gzip = false and pv.csslink = false and pv.css_len > 0 then
			v_wlen := pv.css_ins;
			dbms_lob.read(pv.entity, pv.css_ins, 1, v_raw);
			v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
			utl_tcp.flush(pv.c);
		
			v_wlen := pv.css_len;
			dbms_lob.read(pv.csstext, v_wlen, 1, v_raw);
			v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
			utl_tcp.flush(pv.c);
		
			v_pos := pv.css_ins;
			for i in 1 .. ceil((v_len - pv.css_ins) / 32767) loop
				v_wlen := t.tf(v_pos + 32767 > v_len, v_len - v_pos, 32767);
				dbms_lob.read(pv.entity, v_wlen, v_pos + 1, v_raw);
				v_pos  := v_pos + v_wlen;
				v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
				utl_tcp.flush(pv.c);
			end loop;
			return;
		end if;
	
		for i in 1 .. ceil(v_len / pv.write_buff_size) loop
			if v_pos + pv.write_buff_size > v_len then
				v_wlen := v_len - v_pos;
			else
				v_wlen := pv.write_buff_size;
			end if;
			if v_gzip then
				dbms_lob.read(pv.gzip_entity, v_wlen, v_pos + 1, v_raw);
			else
				dbms_lob.read(pv.entity, v_wlen, v_pos + 1, v_raw);
			end if;
			v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
			utl_tcp.flush(pv.c);
			v_pos := v_pos + v_wlen;
		end loop;
	end do_write;

	procedure finish is
		v_len  integer;
		v_len2 integer := 0;
		v_raw  raw(32767);
		v_amt  number(8) := 99999999;
		v_gzip boolean := false;
		v_md5  varchar2(32);
		v_lzh  binary_integer;
		v_read binary_integer;
		v_pos  number := 0;
	begin
		-- if use stream, flush the final buffered content and the end marker out
		if pv.use_stream then
			v_len := utl_tcp.write_line(pv.c, pv.end_marker);
			utl_tcp.flush(pv.c);
			return;
		end if;
	
		-- when no content, just return;
		v_len := pv.buffered_length;
		if v_len = 0 then
			goto print_http_headers;
		end if;
	
		if pv.csslink is not null then
			if pv.css_len > 0 then
				if pv.csslink then
					-- compute md5 digest and replace css/xxx54
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
	
		if r.type != 'c' and (r.header('accept-encoding') like '%gzip%') and v_len + v_len2 > pv.gzip_thres then
			v_gzip := true;
			if v_len2 = 0 then
				dbms_lob.erase(pv.entity, v_amt, pv.buffered_length + 1);
				pv.gzip_entity := utl_compress.lz_compress(pv.entity, 1);
			else
				v_lzh  := utl_compress.lz_compress_open(pv.gzip_entity, 1);
				v_read := pv.css_ins;
				dbms_lob.read(pv.entity, v_read, 1, v_raw);
				utl_compress.lz_compress_add(v_lzh, pv.gzip_entity, v_raw);
				v_read := pv.css_len;
				dbms_lob.read(pv.csstext, v_read, 1, v_raw);
				utl_compress.lz_compress_add(v_lzh, pv.gzip_entity, v_raw);
				v_pos := pv.css_ins;
				for i in 1 .. ceil((v_len - pv.css_ins) / 32767) loop
					v_read := t.tf(v_pos + 32767 > v_len, v_len - v_pos, 32767);
					dbms_lob.read(pv.entity, v_read, v_pos + 1, v_raw);
					v_pos := v_pos + v_read;
					utl_compress.lz_compress_add(v_lzh, pv.gzip_entity, v_raw);
				end loop;
				utl_compress.lz_compress_close(v_lzh, pv.gzip_entity);
			end if;
			v_len := dbms_lob.getlength(pv.gzip_entity);
			h.content_encoding_gzip;
		end if;
	
		if pv.content_md5 = true or pv.etag_md5 = true then
			if v_gzip then
				dbms_lob.trim(pv.gzip_entity, v_len);
				v_raw := dbms_crypto.hash(pv.gzip_entity, dbms_crypto.hash_md5);
			else
				dbms_lob.trim(pv.entity, v_len);
				v_raw := dbms_crypto.hash(pv.entity, dbms_crypto.hash_md5);
			end if;
			v_md5 := utl_raw.cast_to_varchar2(utl_encode.base64_encode(v_raw));
			if pv.content_md5 = true then
				pv.headers('Content-MD5') := v_md5;
			end if;
			if pv.etag_md5 = true then
				if r.etag = v_md5 then
					h.status_line(304);
					v_len := 0;
				else
					h.etag(v_md5);
				end if;
			end if;
		end if;
	
		<<print_http_headers>>
		pv.headers('Content-Length') := to_char(v_len + v_len2);
		pv.headers('x-pw-elapsed-time') := to_char((dbms_utility.get_time - pv.elpt) * 10) || ' ms';
		pv.headers('x-pw-cpu-time') := to_char((dbms_utility.get_cpu_time - pv.cput) * 10) || ' ms';
	
		-- have content, but have feedback indication or _c
		if pv.end_marker != 'feedback' and r.type = 'c' then
		if v_len > 0 and r.type = 'c' and pv.end_marker != 'feedback' then
			declare
				v  varchar2(4000);
				nl varchar2(2) := chr(13) || chr(10);
				l  pls_integer;
			begin
				-- write fixed head
				v := '303' || nl || 'Date: ' || t.hdt2s(sysdate) || nl;
				v := v || 'Content-Length: 0' || nl;
				v := v || 'Location: feedback?id=' || nl;
				v := v || 'Cache-Control: no-cache' || nl;
				l := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
				utl_tcp.flush(pv.c);
			end;
			return;
		end if;
	
		do_write(v_len, v_gzip);
	end;

end output;
/
