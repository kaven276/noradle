create or replace package body p is

	procedure "_init"(passport pls_integer) is
	begin
		if passport != 80526 then
			raise_application_error(-20000, 'can not call psp.web''s internal method');
		end if;
		pv.buffered_length := 0;
	end;

	-- public
	procedure line(str varchar2) is
		dummy pls_integer;
		v_out varchar2(4000);
	begin
		if not pv.allow_content then
			raise_application_error(-20001, 'Content-Type not set in http header, but want to write http body');
		end if;
	
		if not pv.use_stream then
			dbms_lob.append(pv.entity, utl_i18n.string_to_raw(str || chr(13), pv.charset_ora));
			return;
		end if;
	
		v_out := convert(str, pv.charset_ora);
	
		if pv.buffered_length + lengthb(v_out) + 2 > pv.write_buff_size then
			utl_tcp.flush(pv.c);
			pv.buffered_length := 0;
		end if;
		dummy              := utl_tcp.write_line(pv.c, v_out);
		pv.buffered_length := pv.buffered_length + lengthb(v_out) + 2;
	
		-- raise_application_error(-20001, 'other than utf/gbk charset is not supported yet');
	end;

	procedure flush is
	begin
		if pv.use_stream then
			utl_tcp.flush(pv.c);
		end if;
	end;

	procedure finish is
		v_len  integer;
		v_wlen number(8);
		v_raw  raw(2048);
	begin
		if pv.use_stream then
			return;
		end if;
	
		v_len := dbms_lob.getlength(pv.entity);
		if (r.header('accept-encoding') like '%gzip%') and v_len > pv.gzip_thres then
			pv.entity := utl_compress.lz_compress(pv.entity, 1);
			v_len     := dbms_lob.getlength(pv.entity);
			h.content_encoding('gzip');
		end if;
		h.content_length(v_len);
	
		pv.headers('x-pw-elapsed-time') := to_char((dbms_utility.get_time - pv.elpt) * 10) || ' ms';
		pv.headers('x-pw-cpu-time') := to_char((dbms_utility.get_cpu_time - pv.cput) * 10) || ' ms';
	
		h.write_head;
		utl_tcp.flush(pv.c);
	
		for i in 1 .. ceil(v_len / pv.write_buff_size) loop
			v_wlen := pv.write_buff_size;
			dbms_lob.read(pv.entity, v_wlen, (i - 1) * pv.write_buff_size + 1, v_raw);
			v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
			utl_tcp.flush(pv.c);
		end loop;
	end;

end p;
/
