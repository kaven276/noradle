create or replace package body bios is

	-- for unit test only
	procedure init_req_pv is
	begin
		ra.params.delete;
		rc.params.delete;
		rb.charset_http := null;
		rb.charset_db   := null;
		rb.blob_entity  := null;
		rb.clob_entity  := null;
		rb.nclob_entity := null;
	end;

	procedure getblob
	(
		p_len  in pls_integer,
		p_blob in out nocopy blob
	) is
		v_pos  pls_integer;
		v_raw  raw(32767);
		v_size pls_integer;
		v_read pls_integer := 0;
		v_rest pls_integer := p_len;
	begin
		rb.charset_http := null;
		rb.charset_db   := null;
		rb.blob_entity  := null;
		rb.clob_entity  := null;
		rb.nclob_entity := null;
	
		v_pos           := instrb(r.header('content-type'), '=');
		rb.charset_http := t.tf(v_pos > 0, trim(substr(r.header('content-type'), v_pos + 1)), 'UTF-8');
		rb.charset_db   := utl_i18n.map_charset(rb.charset_http, utl_i18n.generic_context, utl_i18n.iana_to_oracle);
		v_pos           := instrb(r.header('content-type') || ';', ';');
		rb.mime_type    := substrb(r.header('content-type'), 1, v_pos - 1);
		rb.length       := r.getn('h$content-length');
	
		dbms_lob.createtemporary(p_blob, cache => true, dur => dbms_lob.call);
		loop
			v_size := utl_tcp.read_raw(pv.c, v_raw, least(32767, v_rest));
			v_rest := v_rest - v_size;
			dbms_lob.writeappend(p_blob, v_size, v_raw);
			exit when v_rest = 0;
		end loop;
	end;

	/**
  for request header frame
  v_type(int8) must be 0 (head frame)
  v_len(int32) is just ignored 
  */
	procedure read_request is
		v_bytes pls_integer;
		v_raw4  raw(4);
		v_slot  pls_integer;
		v_type  raw(1);
		v_flag  raw(1);
		v_len   pls_integer;
		v_name  varchar2(1000);
		v_value varchar2(32000);
		v_count pls_integer;
		v_hprof varchar2(30);
		v_st    st;
		procedure read_wrapper is
		begin
			v_bytes := utl_tcp.read_raw(pv.c, v_raw4, 4, false);
			v_slot  := trunc(utl_raw.cast_to_binary_integer(v_raw4) / 65536);
			v_type  := utl_raw.substr(v_raw4, 3, 1);
			v_flag  := utl_raw.substr(v_raw4, 4, 1);
			v_bytes := utl_tcp.read_raw(pv.c, v_raw4, 4, false);
			v_len   := utl_raw.cast_to_binary_integer(v_raw4);
			--k_debug.trace(st('read_wrapper', v_slot, v_type, v_flag, v_len), 'dispatcher');
		end;
	begin
		read_wrapper;
		k_debug.time_header_init;
		pv.cslot_id := v_slot;
		pv.protocol := utl_tcp.get_line(pv.c, true);
		v_hprof     := utl_tcp.get_line(pv.c, true);
		pv.hp_flag  := v_hprof is not null;
		--k_debug.trace(st('protocol/hprof', pv.protocol, t.tf(pv.hp_flag, 'true', 'false')), 'dispatcher');
	
		ra.params.delete;
		rc.params.delete;
		loop
			v_name  := trim(utl_tcp.get_line(pv.c, true));
			v_value := utl_tcp.get_line(pv.c, true);
			exit when v_name is null;
			if v_name like '*%' then
				v_name  := substrb(v_name, 2);
				v_count := to_number(v_value);
				v_st    := st();
				v_st.extend(v_count);
				for i in 1 .. v_count loop
					v_st(i) := utl_tcp.get_line(pv.c, true);
				end loop;
			else
				v_st := st(v_value);
			end if;
			ra.params(v_name) := v_st;
		end loop;
	
		if pv.cslot_id > 0 then
			-- noradle request have i$cid send without frame wrapper
			v_value := utl_tcp.get_line(pv.c, true);
			ra.params('b$cid') := st(v_value);
			v_value := utl_tcp.get_line(pv.c, true);
			ra.params('b$cslot') := st(v_value);
		end if;
	
		loop
			read_wrapper;
			exit when v_len = 0;
			--k_debug.trace(st('getblob', v_len), 'dispatcher');
			getblob(v_len, rb.blob_entity);
		end loop;
	
	end;

	procedure wpi(i binary_integer) is
	begin
		pv.wlen := utl_tcp.write_raw(pv.c, utl_raw.cast_from_binary_integer(i));
	end;

	procedure write_frame(ftype pls_integer) is
	begin
		wpi(pv.cslot_id * 256 * 256 + ftype * 256 + 0);
		wpi(0);
	end;

	procedure write_frame
	(
		ftype pls_integer,
		v     in out nocopy varchar2
	) is
	begin
		wpi(pv.cslot_id * 256 * 256 + ftype * 256 + 0);
		if v is not null then
			wpi(lengthb(v));
			pv.wlen := utl_tcp.write_text(pv.c, v);
		end if;
		-- pv.wlen := utl_tcp.write_raw(pv.c, hextoraw(pv.bom));
	end;

	procedure write_end is
	begin
		wpi(pv.cslot_id * 256 * 256 + 255 * 256 + 0);
		wpi(0);
	end;

	procedure write_head is
		v  varchar2(4000);
		nl varchar2(2) := chr(13) || chr(10);
		n  varchar2(30);
		cc varchar2(100) := '';
	begin
		v := pv.status_code || nl || 'Date: ' || t.hdt2s(sysdate) || nl;
		n := pv.headers.first;
		while n is not null loop
			v := v || n || ': ' || pv.headers(n) || nl;
			n := pv.headers.next(n);
		end loop;
		n := pv.caches.first;
		while n is not null loop
			if pv.caches(n) = 'Y' then
				cc := cc || ', ' || n;
			else
				cc := cc || ', ' || n || '=' || pv.caches(n);
			end if;
			n := pv.caches.next(n);
		end loop;
		if cc is not null then
			v := v || 'Cache-Control: ' || substrb(cc, 3) || nl;
		end if;
		n := pv.cookies.first;
		if n is not null then
			v := v || 'Set-Cookies: ' || nl;
		end if;
		while n is not null loop
			v := v || pv.cookies(n) || nl;
			n := pv.cookies.next(n);
		end loop;
		if pv.entry is null then
			dbms_output.put_line(v);
		else
			write_frame(0, v);
		end if;
	end;

	procedure write_session is
		nl varchar2(2) := chr(13) || chr(10);
		n  varchar2(30);
		v  varchar2(4000) := 'n: v' || nl;
	begin
		n := rc.params.first;
		while n is not null loop
			v := v || n || ': ' || t.join(rc.params(n), '~') || nl;
			n := rc.params.next(n);
		end loop;
		write_frame(2, v);
	end;

end bios;
/
