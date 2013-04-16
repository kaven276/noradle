create or replace package body gateway is

	/* main functions
  0. establish connection to nodejs and listen for request
  1. control lifetime by max requests and max runtime
  2. switch to target user current_schema
  3. collect request cpu/ellapsed time
  4. collect hprof statistics
  */

	-- private
	procedure make_conn
	(
		c    in out nocopy utl_tcp.connection,
		flag pls_integer
	) is
		v_sid pls_integer;
		v_seq pls_integer;
		function pi2r(i binary_integer) return raw is
		begin
			return utl_raw.cast_from_binary_integer(i);
		end;
	begin
		c := utl_tcp.open_connection(remote_host     => k_cfg.server_control().gw_host,
																 remote_port     => k_cfg.server_control().gw_port,
																 charset         => null,
																 in_buffer_size  => 32767,
																 out_buffer_size => 0,
																 tx_timeout      => 3);
		select a.sid, a.serial# into v_sid, v_seq from v$session a where a.sid = sys_context('userenv', 'sid');
		pv.wlen := utl_tcp.write_raw(c, utl_raw.concat(pi2r(197610261), pi2r(v_sid), pi2r(v_seq), pi2r(pv.in_seq * flag)));
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
			into pv.cfg_id, pv.in_seq
			from user_scheduler_running_jobs a
		 where a.session_id = sys_context('userenv', 'sid');
		pv.svr_req_cnt := 0;
		pv.svr_stime   := sysdate;
	
		dbms_alert.register('PW_STOP_SERVER');
		v_trc := pv.cfg_id || '-' || pv.in_seq || '.trc';
	
		<<make_connection>>
		begin
			make_conn(pv.c, 1);
		exception
			when utl_tcp.network_error then
				if get_alert_quit then
					goto the_end; -- prevent endless connect fail&retry, allow quit
				end if;
				dbms_lock.sleep(3);
				goto make_connection;
		end;
	
		loop
			<<read_request>>
		
			-- check if max lifetime reach
			if sysdate > pv.svr_stime + k_cfg.server_control().max_lifetime then
				goto the_end;
			end if;
		
			-- check if stop singal arrived
			if get_alert_quit then
				goto the_end;
			end if;
		
			-- accept arrival of new request
			begin
				pv.protocol := utl_tcp.get_line(pv.c, true);
			exception
				when utl_tcp.transfer_timeout then
					goto read_request;
				when utl_tcp.end_of_input then
					goto make_connection;
				when utl_tcp.network_error then
					goto make_connection;
			end;
		
			v_hprof := k_cfg.server_control().hprof;
			if v_hprof is not null then
				dbms_hprof.start_profiling('PLSHPROF_DIR', v_trc);
				pv.hp_label := '';
			end if;
		
			$if k_ccflag.use_time_stats $then
			pv.elpt := dbms_utility.get_time;
			pv.cput := dbms_utility.get_cpu_time;
			$end
		
			-- read & parse request info and do init work
			pv.firstpg := true;
			begin
				case pv.protocol
					when 'quit_process' then
						goto the_end;
					when 'HTTP' then
						http_server.serv;
					when 'DATA' then
						data_server.serv;
					else
						begin
							execute immediate 'call ' || pv.protocol || '_server.serv()';
						exception
							when pv.ex_invalid_proc then
								any_server.serv;
						end;
				end case;
			exception
				when pv.ex_continue then
					continue; -- give up current request service
				when pv.ex_quit then
					goto the_end;
				when others then
					k_debug.trace(st('page before exection', pv.protocol, sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
					goto the_end;
			end;
			pv.firstpg := false;
			-- do all pv init beforehand, next call to page init will not be first page
		
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
					-- system(not app level) exception occurred
					k_debug.trace(st('page exception', r.url, pv.cfg_id, sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
					execute immediate 'call ' || pv.protocol || '_server.onex(:1,:2)'
						using sqlcode, sqlerrm;
			end;
		
			if p.gv_xhtp then
				p.ensure_close;
			end if;
			output.finish;
		
			if v_hprof is not null then
				dbms_hprof.stop_profiling;
				tmp.s := nvl(pv.hp_label, 'psp.web://' || r.dbu || '/' || r.prog);
				tmp.n := dbms_hprof.analyze('PLSHPROF_DIR', v_trc, run_comment => tmp.s);
			end if;
		
			pv.svr_req_cnt := pv.svr_req_cnt + 1;
			if pv.svr_req_cnt >= k_cfg.server_control().max_requests then
				goto the_end;
			end if;
		
			-- keep sync with nodejs
			begin
				v_req_ender := utl_tcp.get_text(pv.c, 16, false);
				if v_req_ender != '-- end of req --' then
					k_debug.trace(st('gateway find wrong fin marker request',
													 v_req_ender,
													 pv.cfg_id,
													 pv.schema || '.' || pv.prog));
					if pv.protocol = 'HTTP' then
						k_debug.trace(st(r.client_addr, r.ua));
					end if;
					utl_tcp.close_connection(pv.c);
					make_conn(pv.c, 1);
				end if;
			exception
				when others then
					k_debug.trace(st('gateway find fin marker error, maybe timeout', pv.cfg_id, pv.schema || '.' || pv.prog));
					utl_tcp.close_connection(pv.c);
					make_conn(pv.c, 1);
			end;
		
		end loop;
	
		<<the_end>>
		utl_tcp.close_all_connections;
	exception
		when others then
			k_debug.trace(st('gateway listen exception', pv.cfg_id, sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
			utl_tcp.close_all_connections;
	end;

end gateway;
/
