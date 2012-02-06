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
		v_tmp pv.gzip_amount%type;
	begin
		v_out := utl_i18n.string_to_raw(str, pv.charset_ora);
		v_len := utl_raw.length(v_out);
	
		dbms_lob.write(pv.entity, v_len, pv.css_len + 1, v_out);
		pv.css_len := pv.css_len + v_len;
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
		v_tmp pv.gzip_amount%type;
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
		v_wlen number(8);
		v_raw  raw(32767);
		v_amt  number(8) := 99999999;
		v_gzip boolean := false;
		v_pos  number := 0;
	begin
		-- when no content, just return;
		v_len := pv.buffered_length;
		if v_len = 0 then
			return;
		end if;
	
		-- if use stream, flush the final buffered content and the end marker out
		if pv.use_stream then
			v_len := utl_tcp.write_line(pv.c, pv.end_marker);
			utl_tcp.flush(pv.c);
			return;
		end if;
	
		if r.type != 'c' and (r.header('accept-encoding') like '%gzip%') and v_len > pv.gzip_thres then
			v_gzip := true;
			dbms_lob.erase(pv.entity, v_amt, pv.buffered_length + 1);
			pv.gzip_entity := utl_compress.lz_compress(pv.entity, 1);
			v_len          := dbms_lob.getlength(pv.gzip_entity);
			h.content_encoding_gzip;
		end if;
	
		pv.headers('Content-Length') := to_char(v_len);
		pv.headers('x-pw-elapsed-time') := to_char((dbms_utility.get_time - pv.elpt) * 10) || ' ms';
		pv.headers('x-pw-cpu-time') := to_char((dbms_utility.get_cpu_time - pv.cput) * 10) || ' ms';
	
		-- have content, but have feedback indication or _c
		if pv.end_marker != 'feedback' and r.type = 'c' then
			declare
				v  varchar2(4000);
				nl varchar2(2) := chr(13) || chr(10);
				l  pls_integer;
				n  varchar2(30);
			begin
				-- write fixed head
				v := '303' || nl || 'Date: ' || t.hdt2s(sysdate) || nl;
				v := v || 'Content-Length: 0' || nl;
				v := v || 'Location: feedback?id=' || nl;
				l := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
        utl_tcp.flush(pv.c);
			end;
			return;
		end if;
	
		do_write(v_len, v_gzip);
	end;

end output;
/
