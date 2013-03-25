create or replace package body k_ext_call is

	-- private
	function pi2r(i binary_integer) return raw is
	begin
		return utl_raw.cast_from_binary_integer(i);
	end;

	procedure write(content in out nocopy raw) is
		v_len pls_integer := utl_raw.length(content);
	begin
		dbms_lob.write(dcopv.msg, v_len, dcopv.pos_tail + 1, content);
		dcopv.pos_tail := dcopv.pos_tail + v_len;
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
	procedure close_tcp is
	begin
		utl_tcp.close_connection(dcopv.con);
	exception
		when others then
			null;
	end;

	-- private
	procedure connect_router_proxy is
		v_sid    pls_integer;
		v_serial pls_integer;
		v_count  pls_integer := 0;
	begin
		close_tcp;
		<<make_connection>>
		v_count := v_count + 1;
		for i in (select * from exthub_config_t a where a.sts = 'Y' order by a.seq asc nulls last) loop
			begin
				dcopv.con := utl_tcp.open_connection(remote_host     => i.host,
																						 remote_port     => i.port,
																						 charset         => null,
																						 in_buffer_size  => 32767,
																						 out_buffer_size => 0,
																						 tx_timeout      => 0);
				-- record which current connected ext-hub is, used when ask to reconnect the particular ext-hub
				dcopv.host := i.host;
				dcopv.port := i.port;
				goto connected;
			exception
				when utl_tcp.network_error then
					if v_count = 1 then
						k_debug.trace(st('connect error (host:port,ausid)',
														 i.host || ':' || i.port,
														 sys_context('userenv', 'sessionid')),
													'DCO');
					end if;
					continue;
			end;
		end loop;
		dbms_lock.sleep(3);
		goto make_connection;
		<<connected>>
		if v_count > 1 then
			k_debug.trace(st('connect after failure (host:port,ausid)',
											 dcopv.host || ':' || dcopv.port,
											 sys_context('userenv', 'sessionid')),
										'DCO');
		end if;
		select a.sid, a.serial# into v_sid, v_serial from v$session a where a.sid = sys_context('userenv', 'sid');
		dcopv.tmp_pi := utl_tcp.write_raw(dcopv.con,
																			utl_raw.concat(pi2r(197610262),
																										 pi2r(v_sid),
																										 pi2r(v_serial),
																										 pi2r(sys_context('userenv', 'sessionid'))));
	end;

	-- private, detect ext-hub quit and try reconnect
	-- as autonomouse transaction to avoid main code in transaction
	procedure check_reconnect is
		pragma autonomous_transaction;
		v_sts number(1);
		v_raw raw(1);
	begin
		dbms_alert.waitone('Noradle-DCO-EXTHUB-QUIT', dcopv.tmp_s, v_sts, 0);
		if v_sts = 0 and dcopv.tmp_s = dcopv.host || ':' || dcopv.port then
			k_debug.trace(st('check_reconnect find quit signal', sys_context('userenv', 'sessionid'), dcopv.onway), 'DCO');
			-- read all pending reply and then reconnect
			loop
				k_debug.trace(st('reading one pending reply', sys_context('userenv', 'sessionid'), dcopv.onway), 'DCO');
				exit when dcopv.onway = 0;
				dcopv.tmp_b := read_response(-1, dcopv.zblb, null);
			end loop;
			connect_router_proxy;
		else
			-- use read test
			begin
				-- This function does not return 
				-- until the specified number of bytes have been read, 
				-- or the end of input has been reached.
				dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_raw, 1, true);
			exception
				when utl_tcp.end_of_input or utl_tcp.network_error then
					k_debug.trace(st('find ext-hub end connection'), 'DCO');
					connect_router_proxy;
				when others then
					null;
			end;
		end if;
		rollback;
	end check_reconnect;

	-- real network I/O write
	procedure flush is
		v_raw  raw(8132);
		v_wlen number(8);
		v_pos  number := 0;
		v_err  number(1) := 0;
	begin
		if dcopv.pos_head <= 12 then
			return; -- no whole request to send, buffer is empty
		end if;
		if dcopv.pos_tail - dcopv.pos_head > 12 then
			raise_application_error(-20000, 'DCO flush attempt in half filled request, action aborted');
		end if;
		check_reconnect;
		v_pos  := 0;
		v_wlen := dcopv.chksz;
		for i in 1 .. ceil(dcopv.pos_head / dcopv.chksz) loop
			if v_pos + dcopv.chksz > dcopv.pos_head then
				v_wlen := dcopv.pos_head - v_pos;
			end if;
			dbms_lob.read(dcopv.msg, v_wlen, v_pos + 1, v_raw);
		
			<<write_tcp>>
			begin
				v_wlen := utl_tcp.write_raw(dcopv.con, v_raw, v_wlen);
			exception
				when utl_tcp.network_error or dcopv.ex_tcp_security then
					k_debug.trace('tcp write error', 'DCO');
					if v_err > 0 then
						raise;
					end if;
					v_err := v_err + 1;
					connect_router_proxy;
					goto write_tcp;
			end;
			v_pos := v_pos + v_wlen;
		end loop;
		k_debug.trace('tcp write a batch', 'DCO');
	
		dcopv.pos_head := 0;
		dcopv.pos_tail := 12;
		dcopv.onway    := dcopv.onway + dcopv.onbuf;
		dcopv.onbuf    := 0;
	end flush;

	-- private
	function send
	(
		proxy_id pls_integer,
		sync     pls_integer,
		buffered boolean
	) return pls_integer is
		v_len pls_integer := dcopv.pos_tail - dcopv.pos_head;
	begin
		if v_len = 0 then
			return 0; -- ignore empty request body
		end if;
		dcopv.rseq := dcopv.rseq + 1;
		dbms_lob.write(dcopv.msg, 4, dcopv.pos_head + 1, pi2r(v_len * sync));
		dbms_lob.write(dcopv.msg, 4, dcopv.pos_head + 5, pi2r(proxy_id));
		dbms_lob.write(dcopv.msg, 4, dcopv.pos_head + 9, pi2r(dcopv.rseq));
		dcopv.onbuf    := dcopv.onbuf + 1;
		dcopv.pos_head := dcopv.pos_tail;
		dcopv.pos_tail := dcopv.pos_tail + 12;
		if not buffered then
			flush;
		end if;
		dcopv.rsps(dcopv.rseq) := null;
		return dcopv.rseq;
	end;

	function send_request
	(
		proxy_id pls_integer,
		buffered boolean := false
	) return pls_integer is
	begin
		return send(proxy_id, 1, buffered);
	end;

	procedure send_request
	(
		proxy_id pls_integer,
		buffered boolean := false
	) is
	begin
		dcopv.tmp_pi := send(proxy_id, -1, buffered);
	end;

	function read_response
	(
		req_seq pls_integer,
		req_blb in out nocopy blob,
		timeout pls_integer := null
	) return boolean is
		v_int32   raw(4);
		v_len     pls_integer;
		v_raw     raw(8132);
		v_rseq    pls_integer;
		v_asid    pls_integer;
		v_timeout number(8) := timeout * 100;
		v_start   number;
	begin
		if dcopv.rsps.exists(req_seq) and dcopv.rsps(req_seq) is not null then
			req_blb := dcopv.rsps(req_seq);
			pdu.start_parse(req_seq);
			return true;
		end if;
		<<read_response>>
		v_start := dbms_utility.get_time;
		if utl_tcp.available(dcopv.con, v_timeout / 100) = 0 then
			return false;
		end if;
		dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_int32, 4);
		v_len      := utl_raw.cast_to_binary_integer(v_int32) - 12;
		dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_int32, 4);
		v_asid     := utl_raw.cast_to_binary_integer(v_int32);
		dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_int32, 4);
		v_rseq     := utl_raw.cast_to_binary_integer(v_int32);
	
		dbms_lob.createtemporary(req_blb, cache => true, dur => dbms_lob.session);
		for i in 1 .. floor(v_len / 8132) loop
			dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_raw, 8132);
			dbms_lob.writeappend(req_blb, 8132, v_raw);
		end loop;
		v_len := mod(v_len, 8132);
		if v_len > 0 then
			dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_raw, v_len);
			dbms_lob.writeappend(req_blb, v_len, v_raw);
		end if;
	
		dcopv.rsps(v_rseq) := req_blb;
		dcopv.onway := dcopv.onway - 1;
		if req_seq = v_rseq then
			pdu.start_parse(req_seq);
			return true;
		elsif dcopv.onway = 0 then
			return false;
		else
			v_timeout := v_timeout - (dbms_utility.get_time - v_start);
			if timeout is null or v_timeout > 0 then
				-- k_debug.trace(st('before time out, continue try'),'DCO');
				goto read_response;
			else
				-- k_debug.trace(st('after time out, abort'),'DCO');
				req_blb := null;
				dcopv.rsps.delete(req_seq);
				return false;
			end if;
		end if;
	end;

	function call_sync
	(
		proxy_id pls_integer,
		req_blb  in out nocopy blob,
		timeout  pls_integer := null
	) return boolean is
	begin
		return read_response(send_request(proxy_id, false), req_blb, timeout);
	end;

end k_ext_call;
/
