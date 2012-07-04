create or replace package body k_ext_call is

	-- private
	function trim_raw
	(
		int32 pls_integer,
		bytes number := 4
	) return raw is
	begin
		return utl_raw.substr(utl_raw.cast_from_binary_integer(int32), 5 - bytes);
	end;

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
		dcopv.tmp_pi := utl_tcp.write_raw(dcopv.con,
																			utl_raw.concat(utl_raw.cast_from_binary_integer(v_sid),
																										 utl_raw.cast_from_binary_integer(v_serial),
																										 utl_raw.cast_from_binary_integer(dcopv.rseq)));
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
			v_cs := 'AL32UTF8';
		end if;
	
		v_out := utl_i18n.string_to_raw(lpad(' ', indent, ' ') || str || nl, v_cs);
		write(v_out);
	end;

	-- private
	function send
	(
		proxy_id pls_integer,
		sync     pls_integer
	) return pls_integer is
		v_raw  raw(32767);
		v_wlen number(8);
		v_pos  number := 0;
	begin
		dcopv.rseq := dcopv.rseq + 1;
		dcopv.rsps(dcopv.rseq) := dcopv.zblb;
		dbms_lob.createtemporary(dcopv.rsps(dcopv.rseq), cache => true, dur => dbms_lob.session);
	
		v_wlen := utl_tcp.write_raw(dcopv.con, trim_raw((dcopv.pos + 4 + 2) * sync, 4));
		v_wlen := utl_tcp.write_raw(dcopv.con, trim_raw(proxy_id, 2));
	
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
		return dcopv.rseq;
	end;

	function send_request(proxy_id pls_integer) return pls_integer is
	begin
		return send(proxy_id, 1);
	end;

	procedure send_request(proxy_id pls_integer) is
	begin
		dcopv.tmp_pi := send(proxy_id, -1);
	end;

	function read_response
	(
		req_seq pls_integer,
		req_blb in out nocopy blob,
		timeout pls_integer := null
	) return boolean is
		v_int32  raw(4);
		v_uint16 raw(2) := hextoraw('0');
		v_len    pls_integer;
		v_raw    raw(8132);
		v_rseq   pls_integer;
	begin
		if utl_tcp.available(dcopv.con, timeout) < 0 then
			return false;
		end if;
		dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_int32, 4);
		dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_uint16, 2);
		v_len      := utl_raw.cast_to_binary_integer(v_int32) - 6;
		v_rseq     := utl_raw.cast_to_binary_integer(v_uint16);
		for i in 1 .. floor(v_len / 8132) loop
			dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_raw, 8132);
			dbms_lob.writeappend(dcopv.rsps(v_rseq), 8132, v_raw);
		end loop;
		v_len := mod(v_len, 8132);
		if v_len > 0 then
			dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_raw, v_len);
			dbms_lob.writeappend(dcopv.rsps(v_rseq), v_len, v_raw);
		end if;
		if req_seq = v_rseq then
			req_blb := dcopv.rsps(v_rseq);
			pdu.start_parse(req_seq);
			return true;
		else
			return false;
		end if;
	end;

	function call_sync
	(
		proxy_id pls_integer,
		req_blb  blob,
		timeout  pls_integer := null
	) return boolean is
	begin
		return false;
	end;

begin
	init;
end k_ext_call;
/
