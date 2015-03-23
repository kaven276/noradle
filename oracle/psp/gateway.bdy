create or replace package body gateway is

	/* main functions
  0. establish connection to nodejs and listen for request
  1. control lifetime by max requests and max runtime
  2. switch to target user current_schema
  3. collect request cpu/ellapsed time
  4. collect hprof statistics
  */

	procedure listen
	(
		cfg_id  varchar2 := null,
		slot_id pls_integer := 1
	) is
		no_dad_auth_entry1 exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry1, -942);
		no_dad_auth_entry2 exception;
		pragma exception_init(no_dad_auth_entry2, -6576);
		no_dad_auth_entry_right exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry_right, -01031);
	
		v_done      boolean := false;
		v_trc       varchar2(99);
		v_clinfo    varchar2(64);
		v_hprof     char(1);
		v_last_time date;
		v_count     pls_integer;
		v_sts       number;
		v_open      boolean;
	
		v_quitting    boolean := false;
		v_reconnect   boolean := false;
		v_svr_stime   date := sysdate;
		v_svr_req_cnt pls_integer := 0;
	
		v_cfg server_control_t%rowtype;
	
		-- private 
		procedure close_conn is
		begin
			if v_open then
				v_open := false;
				utl_tcp.close_connection(pv.c);
			end if;
		exception
			when utl_tcp.network_error then
				null;
				k_debug.trace(st('close_conn_error', 'utl_tcp.network_error'), 'keep_conn');
			when others then
				k_debug.trace(st('close_conn_error', sqlcode, sqlerrm), 'keep_conn');
		end;
	
		-- private
		procedure make_conn
		(
			c    in out nocopy utl_tcp.connection,
			flag pls_integer
		) is
			v_sid  pls_integer;
			v_seq  pls_integer;
			v_inst pls_integer;
			v_spid pls_integer;
			v_all  varchar2(200);
			function pi2r(i binary_integer) return raw is
			begin
				return utl_raw.cast_from_binary_integer(i);
			end;
		begin
			dbms_application_info.set_module('utl_tcp', 'open_connection');
			c := utl_tcp.open_connection(remote_host     => v_cfg.gw_host,
																	 remote_port     => v_cfg.gw_port,
																	 charset         => null,
																	 in_buffer_size  => 32767,
																	 out_buffer_size => 0,
																	 tx_timeout      => 1);
			select s.sid, s.serial#, p.spid
				into v_sid, v_seq, v_spid
				from v$session s, v$process p
			 where s.paddr = p.addr
				 and s.sid = sys_context('userenv', 'sid');
			v_inst := nvl(sys_context('USER_ENV', 'INSTANCE'), -1);
			v_all  := sys_context('USERENV', 'DB_NAME') || '/' || sys_context('USERENV', 'DB_DOMAIN') || '/' ||
								sys_context('USERENV', 'DB_UNIQUE_NAME') || '/' || sys_context('USERENV', 'DATABASE_ROLE') || '/080526';
		
			pv.wlen := utl_tcp.write_raw(c,
																	 utl_raw.concat(pi2r(197610261),
																									pi2r(v_sid),
																									pi2r(v_seq),
																									pi2r(v_spid),
																									pi2r(pv.in_seq * flag),
																									pi2r(floor((sysdate - v_svr_stime) * 24 * 60)),
																									pi2r(v_svr_req_cnt),
																									pi2r(v_inst),
																									pi2r(lengthb(v_all))));
			pv.wlen := utl_tcp.write_text(pv.c, v_all);
			v_open  := true;
		end;
	
		function get_alert_quit return boolean is
		begin
			v_sts := dbms_pipe.receive_message(v_clinfo, 0);
			return v_sts = 0;
		end;
	
		procedure quit is
		begin
			raise_application_error(-20526, '');
		end;
	
	begin
		execute immediate 'alter session set nls_date_format="yyyy-mm-dd hh24:mi:ss"';
		if cfg_id is null then
			select substr(a.job_name, 9, lengthb(a.job_name) - 8 - 5), to_number(substr(a.job_name, -4))
				into pv.cfg_id, pv.in_seq
				from user_scheduler_running_jobs a
			 where a.session_id = sys_context('userenv', 'sid');
		else
			pv.cfg_id := cfg_id;
			pv.in_seq := slot_id;
		end if;
	
		---dbms_alert.register('PW_STOP_SERVER');
		v_trc    := pv.cfg_id || '-' || pv.in_seq || '.trc';
		v_clinfo := 'Noradle-' || pv.cfg_id || '#' || pv.in_seq;
		select count(*) into v_count from v$session a where a.client_info = v_clinfo;
		if v_count > 0 then
			dbms_output.put_line('Noradle Server Status:inuse.');
			return;
		end if;
		dbms_application_info.set_client_info(v_clinfo);
		dbms_application_info.set_module('free', null);
		dbms_pipe.purge(v_clinfo);
		k_cfg.server_control(v_cfg);
	
		<<make_connection>>
		begin
			close_conn;
			make_conn(pv.c, 1);
			v_last_time := sysdate;
		exception
			when utl_tcp.network_error then
				if get_alert_quit then
					quit; -- prevent endless connect fail&retry, allow quit
				end if;
				dbms_lock.sleep(3);
				if sysdate > v_svr_stime + v_cfg.max_lifetime then
					quit;
				end if;
				goto make_connection;
		end;
	
		v_quitting := false;
		dbms_application_info.set_module('utl_tcp', 'get_line');
	
		loop
			-- accept arrival of new request
			<<read_request>>
			null;
		
			-- check if max lifetime reached
			-- check if max requests reached
			-- check if stop singal arrived
			-- after previous process and wait timeout
			if v_quitting then
				-- quit immediately
				quit;
			elsif sysdate > v_svr_stime + v_cfg.max_lifetime or v_svr_req_cnt >= v_cfg.max_requests or get_alert_quit then
				-- signal quit, but allow this loop of read request
				pv.wlen := utl_tcp.write_raw(pv.c, utl_raw.cast_from_binary_integer(-1));
				utl_tcp.flush(pv.c);
				v_quitting := true;
			end if;
		
			begin
				pv.protocol := utl_tcp.get_line(pv.c, true);
				v_last_time := sysdate;
				v_reconnect := false;
			exception
				when utl_tcp.transfer_timeout then
					k_cfg.server_control(v_cfg);
					-- if target node or NATs suddenly abort, like lost of power
					-- they will not send fin to socket
					-- when they restart, ogw will not know and wait silly forever
					-- so timeout and reconnect design is needed
					if (sysdate - v_last_time) * 24 * 60 * 60 > v_cfg.idle_timeout then
						k_debug.trace(st('utl_tcp.transfer_timeout', v_trc, 'reconnect'), 'keep_conn');
						if v_reconnect then
							goto make_connection;
						end if;
						pv.wlen := utl_tcp.write_raw(pv.c, utl_raw.cast_from_binary_integer(-1));
						utl_tcp.flush(pv.c);
						v_reconnect := true;
					end if;
					goto read_request;
				when utl_tcp.end_of_input then
					k_debug.trace(st('utl_tcp.end_of_input', v_trc), 'keep_conn');
					-- not sleep will cause reconnect raise ORA-29260 TNS no listener
					dbms_lock.sleep(1);
					goto make_connection;
				when utl_tcp.network_error then
					k_debug.trace(st('utl_tcp.network_error', v_trc), 'keep_conn');
					goto make_connection;
			end;
		
			if pv.protocol = 'QUIT' then
				quit;
			end if;
		
			v_svr_req_cnt := v_svr_req_cnt + 1;
		
			v_hprof := utl_tcp.get_line(pv.c, true);
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
					quit;
				when others then
					k_debug.trace(st('page before exection',
													 pv.protocol,
													 r.url,
													 sqlcode,
													 sqlerrm,
													 dbms_utility.format_error_backtrace));
					quit;
			end;
			pv.firstpg := false;
			-- do all pv init beforehand, next call to page init will not be first page
			k_mapping.set;
		
			-- this is for become user
			v_done := false;
			r.after_map;
			dbms_application_info.set_module(r.dbu || '.' || nvl(r.pack, r.proc), t.tf(r.pack is null, 'standalone', r.proc));
			dbms_session.set_identifier(v_clinfo);
			dbms_session.set_context('SERVER_PROCESS', 'start_time', sysdate, null, v_clinfo);
		
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
					-- system(not app level) exception occurred
					k_debug.trace(st('page exception', r.url, pv.cfg_id, sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
					execute immediate 'call ' || pv.protocol || '_server.onex(:1,:2)'
						using sqlcode, sqlerrm;
			end;
		
			output.finish;
			utl_tcp.flush(pv.c);
			dbms_application_info.set_module('utl_tcp', 'get_line');
			dbms_session.set_identifier(v_clinfo);
			dbms_session.clear_context('SERVER_PROCESS', v_clinfo);
		
			if v_hprof is not null then
				dbms_hprof.stop_profiling;
				tmp.s := nvl(pv.hp_label, 'psp.web://' || r.dbu || '/' || r.prog);
				tmp.n := dbms_hprof.analyze('PLSHPROF_DIR', v_trc, run_comment => tmp.s);
			end if;
		
		end loop;
	
	exception
		when others then
			dbms_application_info.set_module('killed', 'server quit');
			utl_tcp.close_all_connections;
			if v_sts = 0 then
				dbms_output.put_line('Noradle Server Status:kill.');
			else
				dbms_output.put_line('Noradle Server Status:restart.');
			end if;
			if sqlcode != -20526 then
				k_debug.trace(st('gateway listen exception', pv.cfg_id, sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
			end if;
	end;

end gateway;
/
