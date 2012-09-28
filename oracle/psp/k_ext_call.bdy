create or replace package body k_ext_call is

	-- private
	function pi2r(i binary_integer) return raw is
	begin
		return utl_raw.cast_from_binary_integer(i);
	end;

	-- private
	function trim_raw
	(
		int32 pls_integer,
		bytes number := 4
	) return raw is
	begin
		return utl_raw.substr(utl_raw.cast_from_binary_integer(int32), 5 - bytes);
	end;

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
		-- k_debug.trace(st('ext_hub try connect'));
		begin
			utl_tcp.close_connection(dcopv.con);
			-- k_debug.trace(st('ext_hub connect closed'));
		exception
			when others then
				-- k_debug.trace(st('ext_hub connect close error'));
				null;
		end;
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
				-- k_debug.trace(st('ext_hub connected'));
				dcopv.host := i.host;
				dcopv.port := i.port;
				goto connected;
			exception
				when utl_tcp.network_error then
					-- k_debug.trace(st('ext_hub connect error'));
					continue;
			end;
		end loop;
		dbms_lock.sleep(3);
		goto make_connection;
		<<connected>>
		select a.sid, a.serial# into v_sid, v_serial from v$session a where a.sid = sys_context('userenv', 'sid');
		dcopv.tmp_pi := utl_tcp.write_raw(dcopv.con, utl_raw.concat(pi2r(197610262), pi2r(v_sid), pi2r(v_serial), pi2r(dcopv.rseq2)));
	end;

	procedure init is
	begin
		dbms_lob.createtemporary(dcopv.msg, cache => true, dur => dbms_lob.session);
		dcopv.chksz := dbms_lob.getchunksize(dcopv.msg);
		dcopv.posbk := 0;
		dcopv.pos   := 6;
		dcopv.rseq  := 1;
		dcopv.rseq2 := 1;
		dcopv.onway := 0;
		dcopv.onbuf := 0;
		dbms_alert.register('Noradle-DCO-EXTHUB-QUIT');
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
	-- as autonomouse transaction to avoid main code in transaction
	procedure check_reconnect is
		pragma autonomous_transaction;
		v_sts number(1);
	begin
		dbms_alert.waitone('Noradle-DCO-EXTHUB-QUIT', dcopv.tmp_s, v_sts, 0);
		if v_sts = 0 and dcopv.tmp_s = dcopv.host || ':' || dcopv.port then
			-- k_debug.trace(st('check_reconnect find exthub quit signal', dcopv.onway));
			-- read all pending reply and then to reconnect
			loop
				-- k_debug.trace(st('reading one pending reply countdown', dcopv.onway));
				exit when dcopv.onway = 0;
				dcopv.tmp_b := read_response(-1, dcopv.zblb, null);
			end loop;
			connect_router_proxy;
		end if;
		rollback;
	end check_reconnect;

	procedure flush is
		v_raw  raw(8132);
		v_wlen number(8);
		v_pos  number := 0;
		v_cnt  number(1) := 0;
	begin
		if dcopv.pos <= 6 then
			return;
		end if;
		check_reconnect;
		<<write_tcp>>
		begin
			v_pos := 0;
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
		exception
			when utl_tcp.network_error or dcopv.ex_tcp_security then
				if v_cnt > 0 then
					raise;
				end if;
				v_cnt := v_cnt + 1;
				dbms_output.put_line('auto conn starting2 dcopv.rseq=' || dcopv.rseq);
				connect_router_proxy;
				goto write_tcp;
		end;
		dcopv.posbk := 0;
		dcopv.pos   := 6;
		dcopv.rseq2 := dcopv.rseq;
		dcopv.onway := dcopv.onway + dcopv.onbuf;
		dcopv.onbuf := 0;
	end flush;

	-- private
	function send
	(
		proxy_id pls_integer,
		sync     pls_integer,
		buffered boolean
	) return pls_integer is
	begin
		dbms_lob.write(dcopv.msg, 4, dcopv.posbk + 1, trim_raw((dcopv.pos - dcopv.posbk) * sync, 4));
		dbms_lob.write(dcopv.msg, 2, dcopv.posbk + 5, trim_raw(proxy_id, 2));
		if buffered then
			dcopv.posbk := dcopv.pos;
			dcopv.pos   := dcopv.pos + 6;
		else
			flush;
		end if;
		dcopv.rsps(dcopv.rseq) := null;
		dcopv.rseq := dcopv.rseq + 1;
		return dcopv.rseq - 1;
	end;

	function send_request
	(
		proxy_id pls_integer,
		buffered boolean := false
	) return pls_integer is
	begin
		dcopv.onbuf := dcopv.onbuf + 1;
		-- k_debug.trace(st('send', dcopv.onway, dcopv.onbuf));
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
		v_uint16  raw(2) := hextoraw('0');
		v_len     pls_integer;
		v_raw     raw(8132);
		v_rseq    pls_integer;
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
		dcopv.onway := dcopv.onway - 1;
		-- k_debug.trace(st('read', dcopv.onway, dcopv.onbuf));
		dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_int32, 4);
		dcopv.rtcp := utl_tcp.read_raw(dcopv.con, v_uint16, 2);
		v_len      := utl_raw.cast_to_binary_integer(v_int32) - 6;
		v_rseq     := utl_raw.cast_to_binary_integer(v_uint16);
		k_debug.trace(st('read rseq', v_rseq));
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
		if req_seq = v_rseq then
			pdu.start_parse(req_seq);
			return true;
		elsif dcopv.onway = 0 then
			return false;
		else
			v_timeout := v_timeout - (dbms_utility.get_time - v_start);
			if timeout is null or v_timeout > 0 then
				goto read_response;
			else
				req_blb := null;
				dcopv.rsps.delete(req_seq);
				return false;
			end if;
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
