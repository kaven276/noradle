create or replace package body k_ext_call is

	-- private
	procedure connect_router_proxy is
		v_sid    pls_integer;
		v_serial pls_integer;
	begin
		utl_tcp.close_all_connections;
		dcopv.con := utl_tcp.open_connection(remote_host     => '192.168.177.1',
																				 remote_port     => 1524,
																				 charset         => null,
																				 in_buffer_size  => 32767,
																				 out_buffer_size => 0,
																				 tx_timeout      => 3);
		select a.sid, a.serial# into v_sid, v_serial from v$session a where a.sid = sys_context('userenv', 'sid');
		tmp.pi := utl_tcp.write_raw(dcopv.con,
																utl_raw.concat(utl_raw.cast_from_binary_integer(v_sid),
																							 utl_raw.cast_from_binary_integer(v_serial)));
		dbms_lock.sleep(1);
	end;

	procedure init is
	begin
		dbms_lob.createtemporary(dcopv.msg, cache => true, dur => dbms_lob.session);
		dcopv.chksz := dbms_lob.getchunksize(dcopv.msg);
		dcopv.pos   := 0;
		connect_router_proxy;
	end;

	procedure write(content in out nocopy raw) is
		v_len pls_integer := utl_raw.length(content);
	begin
		k_debug.trace(st(v_len, dcopv.pos + 1, pv.cs_utf8));
		dbms_lob.write(dcopv.msg, v_len, dcopv.pos + 1, content);
		dcopv.pos := dcopv.pos + v_len;
	end;

	procedure line
	(
		str    varchar2 character set any_cs,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	) is
		v_out raw(32767);
		v_len pls_integer;
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
		v_wlen := utl_tcp.write_raw(dcopv.con, utl_raw.cast_from_binary_integer(dcopv.pos + 8));
		v_wlen := utl_tcp.write_raw(dcopv.con, utl_raw.cast_from_binary_integer(proxy_id));
		for i in 1 .. ceil(dcopv.pos / dcopv.chksz) loop
			if v_pos + dcopv.chksz > dcopv.pos then
				v_wlen := dcopv.pos - v_pos;
			else
				v_wlen := dcopv.chksz;
			end if;
			dbms_lob.read(dcopv.msg, v_wlen, v_pos + 1, v_raw);
			v_wlen := utl_tcp.write_raw(dcopv.con, v_raw, v_wlen);
			v_pos  := v_pos + v_wlen;
		end loop;
		dcopv.pos := 0;
	end;

begin
	init;
end k_ext_call;
/
