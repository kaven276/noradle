create or replace package body k_ext_call is

	-- private
	procedure connect_router_proxy is
		l        pls_integer;
		v_sid    pls_integer;
		v_serial pls_integer;
	begin
		utl_tcp.close_all_connections;
		pv.outcon := utl_tcp.open_connection(remote_host     => '192.168.177.1',
																				 remote_port     => 1524,
																				 charset         => null,
																				 in_buffer_size  => dbms_lob.getchunksize(pv.outmsg),
																				 out_buffer_size => 0,
																				 tx_timeout      => 3);
		select a.sid, a.serial# into v_sid, v_serial from v$session a where a.sid = sys_context('userenv', 'sid');
		l := utl_tcp.write_raw(pv.outcon,
													 utl_raw.concat(utl_raw.cast_from_binary_integer(v_sid),
																					utl_raw.cast_from_binary_integer(v_serial)));
		dbms_lock.sleep(1);
	end;

	procedure init is
	begin
		dbms_lob.createtemporary(pv.outmsg, cache => true, dur => dbms_lob.session);
		pv.outpos := 0;
		connect_router_proxy;
	end;

	procedure write(content in out nocopy raw) is
		v_len pls_integer := utl_raw.length(content);
	begin
		k_debug.trace(st(v_len, pv.outpos + 1, pv.cs_utf8));
		dbms_lob.write(pv.outmsg, v_len, pv.outpos + 1, content);
		pv.outpos := pv.outpos + v_len;
	end;

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
		v_cs  varchar2(30);
	begin
		if str is null and nl is null then
			return;
		end if;
	
		v_len := lengthb(str);
		if v_len = length(str) then
			v_cs := null;
		else
			v_cs := pv.cs_utf8;
		end if;
	
		v_out := utl_i18n.string_to_raw(lpad(' ', indent, ' ') || str || nl, pv.cs_utf8);
		write(v_out);
	end;

	procedure send(proxy_id pls_integer) is
		v_raw  raw(32767);
		v_wlen number(8);
		v_pos  number := 0;
	begin
		v_wlen := utl_tcp.write_raw(pv.outcon, utl_raw.cast_from_binary_integer(pv.outpos + 8));
		v_wlen := utl_tcp.write_raw(pv.outcon, utl_raw.cast_from_binary_integer(proxy_id));
		for i in 1 .. ceil(pv.outpos / pv.write_buff_size) loop
			if v_pos + pv.write_buff_size > pv.outpos then
				v_wlen := pv.outpos - v_pos;
			else
				v_wlen := pv.write_buff_size;
			end if;
			dbms_lob.read(pv.outmsg, v_wlen, v_pos + 1, v_raw);
			v_wlen := utl_tcp.write_raw(pv.outcon, v_raw, v_wlen);
			v_pos  := v_pos + v_wlen;
		end loop;
		pv.outpos := 0;
	end;

begin
	init;
end k_ext_call;
/
