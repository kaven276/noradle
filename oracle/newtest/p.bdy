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
	begin
		if not pv.allow_content then
			raise_application_error(-20001, 'Content-Type not set in http header, but want to write http body');
		end if;
	
		if not pv.use_stream then
			dbms_lob.append(pv.buf_clob, str || chr(13));
			return;
		end if;
	
		if pv.charset = 'UTF-8' then
			if pv.buffered_length + lengthb(str) * 1.5 + 2 > pv.write_buff_size then
				utl_tcp.flush(pv.c);
				pv.buffered_length := 0;
			end if;
			dummy              := utl_tcp.write_line(pv.c, str);
			pv.buffered_length := pv.buffered_length + lengthb(str) * 1.5 + 2;
		elsif pv.charset = 'GBK' then
			if pv.buffered_length + lengthb(str) + 2 > pv.write_buff_size then
				utl_tcp.flush(pv.c);
				pv.buffered_length := 0;
			end if;
			dummy := utl_tcp.write_line(pv.c, str);
			-- dummy       := utl_tcp.write_raw(c, utl_i18n.string_to_raw(str || chr(13)));
			pv.buffered_length := pv.buffered_length + lengthb(str) + 2;
		else
			raise_application_error(-20001, 'other than utf/gbk charset is not supported yet');
		end if;
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
		v_part nvarchar2(2048);
		v_raw  raw(2048);
	
		v_blob     blob;
		v_dest_os  integer := 1;
		v_src_os   integer := 1;
		v_amount   integer := dbms_lob.lobmaxsize;
		v_csid     number := 0; -- nvl(nls_charset_id(dad_charset), 0);
		v_lang_ctx integer := 0;
		v_warning  integer;
		v_num      number(6);
	begin
		if pv.use_stream then
			return;
		end if;
	
		if (r.header('accept-encoding') like '%gzip%') and dbms_lob.getlength(pv.buf_clob) > pv.gzip_thres then
			dbms_lob.createtemporary(v_blob, true, dbms_lob.call);
			dbms_lob.converttoblob(v_blob, pv.buf_clob, v_amount, v_dest_os, v_src_os, v_csid, v_lang_ctx, v_warning);
			v_blob := utl_compress.lz_compress(v_blob, 1);
			v_len  := dbms_lob.getlength(v_blob);
			h.content_encoding('gzip');
			if true then
				h.content_length(v_len);
			else
				h.transfer_encoding_chunked;
			end if;
			h.header('x-bytes', v_len);
			h.write_head;
			utl_tcp.flush(pv.c);
			-- dbms_lock.sleep(0);
		
			for i in 1 .. ceil(v_len / pv.write_buff_size) loop
				v_wlen := pv.write_buff_size;
				dbms_lob.read(v_blob, v_wlen, (i - 1) * pv.write_buff_size + 1, v_raw);
				dbms_pipe.pack_message(v_wlen);
				v_wlen := utl_tcp.write_raw(pv.c, v_raw, v_wlen);
				dbms_pipe.pack_message(v_wlen);
				v_amount := dbms_pipe.send_message('node2psp');
				utl_tcp.flush(pv.c);
			end loop;
		else
			v_len := dbms_lob.getlength(pv.buf_clob);
			h.transfer_encoding_chunked;
			h.header('x-characters', v_len);
			h.write_head;
		
			dbms_pipe.pack_message('clob');
			v_amount := dbms_pipe.send_message('node2psp');
		
			for i in 1 .. ceil(v_len / pv.write_buff_size) loop
				v_wlen := 2048;
				dbms_lob.read(pv.buf_clob, v_wlen, (i - 1) * 2048 + 1, v_part);
				v_wlen := utl_tcp.write_text(pv.c, v_part, v_wlen);
				utl_tcp.flush(pv.c);
			end loop;
		end if;
	end;

end p;
/
