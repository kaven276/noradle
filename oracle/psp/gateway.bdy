create or replace package body gateway is

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
		v_result := utl_tcp.write_raw(c,
																	utl_raw.concat(pi2r(197610261), pi2r(v_sid), pi2r(v_serial), pi2r(pv.seq_in_id * flag)));
	end;

	-- Refactored procedure quit
	function get_alert_quit return boolean is
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

	function client_allow_quit return boolean is
		c   utl_tcp.connection;
		rpl char(1);
		len pls_integer;
	begin
		make_conn(c, -1);
		len := utl_tcp.read_text(c, rpl, 1);
		utl_tcp.close_connection(c);
		return rpl = 'Y';
	end;

	procedure listen is
		no_dad_auth_entry1 exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry1, -942);
		no_dad_auth_entry2 exception;
		pragma exception_init(no_dad_auth_entry2, -6576);
		no_dad_auth_entry_right exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry_right, -01031);
		v_done      boolean := false;
		v_req_ender varchar2(30);
		v_trc       varchar2(99);
		v_hprof     char(1);
	begin
		select substr(a.job_name, 9, lengthb(a.job_name) - 8 - 5), to_number(substr(a.job_name, -4))
			into pv.cur_cfg_id, pv.seq_in_id
			from user_scheduler_running_jobs a
		 where a.session_id = sys_context('userenv', 'sid');
		v_trc := pv.cur_cfg_id || '-' || pv.seq_in_id;
	
		dbms_alert.register('PW_STOP_SERVER');
		pv.svr_request_count := 0;
		pv.svr_start_time    := sysdate;
		<<make_connection>>
		begin
			make_conn(pv.c, 1);
		exception
			when utl_tcp.network_error then
				if get_alert_quit then
					goto the_end;
				end if;
				dbms_lock.sleep(3);
				goto make_connection;
		end;
	
		loop
			<<read_request>>
		
			if sysdate > pv.svr_start_time + k_cfg.server_control().max_lifetime and client_allow_quit then
				goto the_end;
			end if;
		
			if get_alert_quit and client_allow_quit then
				goto the_end;
			end if;
		
			begin
				pv.protocol := utl_tcp.get_line(pv.c, true);
			exception
				when utl_tcp.transfer_timeout then
					goto read_request;
				when utl_tcp.end_of_input then
					goto make_connection;
				when utl_tcp.network_error then
					goto the_end;
			end;
		
			v_hprof := k_cfg.server_control().hprof;
			if v_hprof is not null then
				dbms_hprof.start_profiling('PLSHPROF_DIR', v_trc || '.trc');
			end if;
		
			$if k_ccflag.use_time_stats $then
			pv.elpl := dbms_utility.get_time;
			pv.cpul := dbms_utility.get_cpu_time;
			$end
		
			begin
				case pv.protocol
					when 'quit_process' then
						return;
					when 'HTTP' then
						http_server.serv;
					when 'DATA' then
						data_server.serv;
					else
						execute immediate 'call ' || pv.protocol || '_server.serv()';
				end case;
			exception
				when pv.ex_continue then
					continue;
				when pv.ex_quit then
					goto the_end;
				when others then
					k_debug.trace(st('protocol,sqlcode,sqlerrm', pv.protocol, sqlcode, sqlerrm));
					goto the_end;
			end;
		
			-- this is for become user
		
			v_done := false;
			<<redo>>
			begin
				execute immediate 'call ' || pv.schema || '.dad_auth_entry()';
			exception
				when no_dad_auth_entry1 or no_dad_auth_entry2 or no_dad_auth_entry_right then
					if v_done then
						raise;
					end if;
					sys.pw.add_dad_auth_entry(pv.schema);
					v_done := true;
					goto redo;
				when others then
					k_debug.trace(st('page exception',
													 r.url,
													 pv.cur_cfg_id,
													 sqlcode,
													 sqlerrm,
													 dbms_utility.format_error_backtrace));
					execute immediate 'call ' || pv.protocol || '_server.onex(:1,:2)'
						using sqlcode, sqlerrm;
			end;
		
			if pv.msg_stream then
				if pv.buffered_length > 0 then
					bkr.emit_msg(true);
				end if;
				goto the_end; -- when stream quit, quit process also, to release resource
			end if;
		
			if p.gv_xhtp then
				p.ensure_close;
			end if;
			output.finish;
		
			if v_hprof is not null then
				dbms_hprof.stop_profiling;
				tmp.n := dbms_hprof.analyze('PLSHPROF_DIR',
																		v_trc || '.trc',
																		run_comment => 'psp.web://' || r.dbu || '/' || r.prog);
			end if;
		
			pv.svr_request_count := pv.svr_request_count + 1;
			if pv.svr_request_count >= k_cfg.server_control().max_requests and client_allow_quit then
				goto the_end;
			end if;
		
			begin
				v_req_ender := utl_tcp.get_text(pv.c, 16, false);
				if v_req_ender != '-- end of req --' then
					k_debug.trace(st('gateway find no fin marker request'));
					utl_tcp.close_connection(pv.c);
					make_conn(pv.c, 1);
				end if;
			exception
				when others then
					k_debug.trace(st('gateway find fin marker error, maybe timeout'));
					utl_tcp.close_connection(pv.c);
					make_conn(pv.c, 1);
			end;
		
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
			output.finish;
			utl_tcp.close_all_connections;
	end;

begin
	pv.pspuser := sys_context('userenv', 'current_schema');

end gateway;
/
