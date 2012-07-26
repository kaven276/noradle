create or replace package body gateway is

	procedure error_not_bch is
	begin
		if pv.msg_stream then
			h.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
		else
			h.allow_get_post;
			h.status_line(403);
			h.content_type('text/plain');
			h.header_close;
			h.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
			output.finish;
		end if;
	end;

	procedure error_invalid_dbu is
	begin
		if pv.msg_stream then
			h.line('The requested DB user "' || r.dbu || '" is not allowed to access');
		else
			h.allow_get_post;
			h.status_line(403);
			h.content_type('text/plain');
			h.header_close;
			h.line('The requested DB user "' || r.dbu || '" is not allowed to access');
			output.finish;
		end if;
	end;

	procedure error_dad_auth_entry
	(
		code number,
		errm varchar2
	) is
	begin
		if pv.msg_stream then
			h.line(r.dbu);
			h.line(r.prog);
			h.line(sqlcode);
			h.line(sqlerrm);
		else
			h.allow_get_post;
			h.status_line(500);
			h.content_type('text/plain');
			h.header_close;
			h.line('in servlet occurred dyna sp call error for dbu : ' || r.dbu);
			h.line('error text = ' || code || '/' || errm);
		end if;
	end;

	-- private
	procedure make_conn
	(
		c    in out nocopy utl_tcp.connection,
		flag pls_integer
	) is
		v_sid    pls_integer;
		v_serial pls_integer;
		v_result pls_integer;
		function pi2r(i binary_integer) return raw is
		begin
			return utl_raw.cast_from_binary_integer(i);
		end;
	begin
		c := utl_tcp.open_connection(remote_host     => k_cfg.server_control().gw_host,
																 remote_port     => k_cfg.server_control().gw_port,
																 charset         => null,
																 in_buffer_size  => pv.write_buff_size,
																 out_buffer_size => 0,
																 tx_timeout      => 3);
		select a.sid, a.serial# into v_sid, v_serial from v$session a where a.sid = sys_context('userenv', 'sid');
		v_result := utl_tcp.write_raw(c, utl_raw.concat(pi2r(v_sid), pi2r(v_serial), pi2r(pv.seq_in_id * flag)));
	end;

	-- Refactored procedure quit
	function quit return boolean is
		v_msg varchar2(1);
		v_sts number;
	begin
		dbms_alert.waitone('PW_STOP_SERVER', v_msg, v_sts, 0);
		if v_sts = 0 then
			dbms_alert.remove('PW_STOP_SERVER');
			return true;
		else
			return false;
		end if;
	end;

	function can_quit return boolean is
		c   utl_tcp.connection;
		rpl char(1);
		len pls_integer;
	begin
		make_conn(c, -1);
		len := utl_tcp.read_text(c, rpl, 1);
		utl_tcp.close_connection(c);
		k_debug.trace(st('allow quit ?', rpl));
		return rpl = 'Y';
	end;

	procedure listen is
		no_dad_auth_entry1 exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry1, -942);
		no_dad_auth_entry2 exception;
		pragma exception_init(no_dad_auth_entry2, -6576);
		no_dad_auth_entry_right exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry_right, -01031);
		v_done boolean := false;
		v_dbuf server_control_t.dbu_filter%type;
	begin
		select substr(a.job_name, 9, lengthb(a.job_name) - 8 - 5), to_number(substr(a.job_name, -4))
			into pv.cur_cfg_id, pv.seq_in_id
			from user_scheduler_running_jobs a
		 where a.session_id = sys_context('userenv', 'sid');
	
		dbms_alert.register('PW_STOP_SERVER');
		pv.svr_request_count := 0;
		pv.svr_start_time    := sysdate;
		<<make_connection>>
		begin
			make_conn(pv.c, 1);
		exception
			when utl_tcp.network_error then
				if quit then
					goto the_end;
				end if;
				dbms_lock.sleep(3);
				goto make_connection;
		end;
	
		loop
			<<read_request>>
		
			if sysdate > pv.svr_start_time + k_cfg.server_control().max_lifetime and can_quit then
				goto the_end;
			end if;
		
			if quit and can_quit then
				goto the_end;
			end if;
		
			begin
				pv.ct_marker := utl_tcp.get_line(pv.c, true);
			exception
				when utl_tcp.transfer_timeout then
					goto read_request;
				when utl_tcp.end_of_input then
					goto make_connection;
				when utl_tcp.network_error then
					goto the_end;
			end;
		
			case pv.ct_marker
				when 'HTTP Call' then
					pv.call_type := 0; -- normal process
				when 'NodeJS Call' then
					pv.call_type := 1;
				when 'feedback' then
					output.finish;
					continue;
				when 'csslink' then
					output.do_css_write;
					continue;
				when 'quit_process' then
					return;
				else
					raise_application_error(-20000, 'wrong call type for ' || pv.ct_marker);
			end case;
		
			pv.elpt := dbms_utility.get_time;
			pv.cput := dbms_utility.get_cpu_time;
			k_init.by_request;
			r."_init"(pv.c, 80526);
			v_done := false;
		
			v_dbuf := k_cfg.server_control().dbu_filter;
			if v_dbuf is not null and not regexp_like(r.dbu, v_dbuf) then
				error_invalid_dbu;
			end if;
		
			if substrb(nvl(r.pack, r.proc), -2) not in ('_c', '_b', '_h') then
				error_not_bch;
				continue;
			end if;
		
			case r.method
				when 'GET' then
					k_http.auto_chunk_max_size;
					k_http.auto_chunk_max_idle;
					k_http.content_encoding_auto;
				when 'POST' then
					k_http.auto_chunk_max_size(null);
					k_http.auto_chunk_max_idle(null);
				else
					null;
			end case;
		
			dbms_application_info.set_module(r.prog, null);
		
			-- this is for become user
			<<redo>>
			begin
				execute immediate 'call ' || r.dbu || '.dad_auth_entry()';
			exception
				when no_dad_auth_entry1 or no_dad_auth_entry2 or no_dad_auth_entry_right then
					if v_done then
						raise;
					end if;
					sys.pw.add_dad_auth_entry(r.dbu);
					v_done := true;
					goto redo;
				when others then
					k_debug.trace(st('page exception',
													 r.url,
													 pv.cur_cfg_id,
													 sqlcode,
													 sqlerrm,
													 dbms_utility.format_error_backtrace));
					error_dad_auth_entry(sqlcode, sqlerrm);
			end;
		
			if pv.msg_stream then
				if pv.buffered_length > 0 then
					bkr.emit_msg(true);
				end if;
				goto the_end; -- when stream quit, quit process also, to release resource
			end if;
			output.finish;
		
			pv.svr_request_count := pv.svr_request_count + 1;
			if pv.svr_request_count >= k_cfg.server_control().max_requests and can_quit then
				goto the_end;
			end if;
		
		end loop;
	
		<<the_end>>
		utl_tcp.close_all_connections;
	exception
		when others then
			k_debug.trace(st('gateway listen exception',
											 pv.cur_cfg_id,
											 sqlcode,
											 sqlerrm,
											 dbms_utility.format_error_backtrace));
			utl_tcp.close_all_connections;
			raise;
	end;

begin
	dbms_lob.createtemporary(pv.entity, cache => true, dur => dbms_lob.session);
	dbms_lob.createtemporary(pv.csstext, cache => true, dur => dbms_lob.session);
	pv.write_buff_size := dbms_lob.getchunksize(pv.entity);

end gateway;
/
