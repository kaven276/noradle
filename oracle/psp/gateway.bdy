create or replace package body gateway is

	/* main functions
  0. establish connection to nodejs and listen for request
  1. control lifetime by max requests and max runtime
  2. switch to target user current_schema
  3. collect request cpu/ellapsed time
  4. collect hprof statistics
  */

	v_cfg server_control_t%rowtype;

	-- private 
	procedure close_conn is
	begin
		utl_tcp.close_connection(pv.c);
	exception
		when utl_tcp.network_error then
			null;
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
		v_all  varchar2(200);
		function pi2r(i binary_integer) return raw is
		begin
			return utl_raw.cast_from_binary_integer(i);
		end;
	begin
		c := utl_tcp.open_connection(remote_host     => v_cfg.gw_host,
																 remote_port     => v_cfg.gw_port,
																 charset         => null,
																 in_buffer_size  => 32767,
																 out_buffer_size => 0,
																 tx_timeout      => 3);
		select a.sid, a.serial# into v_sid, v_seq from v$session a where a.sid = sys_context('userenv', 'sid');
		v_inst  := nvl(sys_context('USER_ENV', 'INSTANCE'), -1);
		v_all   := sys_context('USERENV', 'DB_NAME') || '/' || sys_context('USERENV', 'DB_DOMAIN') || '/' ||
							 sys_context('USERENV', 'DB_UNIQUE_NAME') || '/' || sys_context('USERENV', 'DATABASE_ROLE');
		pv.wlen := utl_tcp.write_raw(c,
																 utl_raw.concat(pi2r(197610261),
																								pi2r(v_sid),
																								pi2r(v_seq),
																								pi2r(pv.in_seq * flag),
																								pi2r(v_inst),
																								pi2r(lengthb(v_all))));
		pv.wlen := utl_tcp.write_text(pv.c, v_all);
	end;

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
		v_req_ender varchar2(30);
		v_trc       varchar2(99);
		v_module    varchar2(48);
		v_hprof     char(1);
		v_last_time date;
		v_dummy     pls_integer;
		v_time      date;
		v_count     pls_integer;
		v_sts       number;
		-- Refactored procedure quit
	
		function get_alert_quit return boolean is
		begin
			v_sts := dbms_pipe.receive_message(v_module, 0);
			return v_sts = 0;
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
		pv.svr_req_cnt := 0;
		pv.svr_stime   := sysdate;
	
		---dbms_alert.register('PW_STOP_SERVER');
		v_trc    := pv.cfg_id || '-' || pv.in_seq || '.trc';
		v_module := 'Noradle-' || pv.cfg_id || '#' || pv.in_seq;
		select count(*) into v_count from v$session a where a.module = v_module;
		if v_count > 0 then
			dbms_output.put_line('Noradle Server Status:inuse.');
			return;
		end if;
		dbms_application_info.set_module(v_module, 'server started');
		dbms_pipe.purge(v_module);
		k_cfg.server_control(v_cfg);
	
		<<make_connection>>
		begin
			close_conn;
			make_conn(pv.c, 1);
			v_last_time := sysdate;
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
			if sysdate > pv.svr_stime + v_cfg.max_lifetime then
				goto the_end;
			end if;
		
			-- check if stop singal arrived
			if get_alert_quit then
				goto the_end;
			end if;
		
			-- accept arrival of new request
			begin
				pv.protocol := utl_tcp.get_line(pv.c, true);
				v_last_time := sysdate;
			exception
				when utl_tcp.transfer_timeout then
					-- if too many time, too long timeout
					-- then close connection
					-- and goto make_connection
					-- so not sily waiting broken connection forever
					k_cfg.server_control(v_cfg);
					if (sysdate - v_last_time) * 24 * 60 * 60 > v_cfg.idle_timeout then
						goto make_connection;
					else
						goto read_request;
					end if;
				when utl_tcp.end_of_input then
					goto make_connection;
				when utl_tcp.network_error then
					goto make_connection;
			end;
		
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
					k_debug.trace(st('page before exection',
													 pv.protocol,
													 r.url,
													 sqlcode,
													 sqlerrm,
													 dbms_utility.format_error_backtrace));
					goto the_end;
			end;
			pv.firstpg := false;
			-- do all pv init beforehand, next call to page init will not be first page
			k_mapping.set;
		
			-- this is for become user
			v_done := false;
			r.after_map;
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
		
			if v_hprof is not null then
				dbms_hprof.stop_profiling;
				tmp.s := nvl(pv.hp_label, 'psp.web://' || r.dbu || '/' || r.prog);
				tmp.n := dbms_hprof.analyze('PLSHPROF_DIR', v_trc, run_comment => tmp.s);
			end if;
		
			pv.svr_req_cnt := pv.svr_req_cnt + 1;
			if pv.svr_req_cnt >= v_cfg.max_requests then
				goto the_end;
			end if;
		
			-- keep sync with nodejs
			v_time := sysdate;
			<<check_end_of_req>>
			begin
				v_req_ender := utl_tcp.get_text(pv.c, 16, false);
				if v_req_ender != '-- end of req --' then
					k_debug.trace(st('gateway find wrong fin marker request',
													 v_req_ender,
													 pv.cfg_id,
													 r.dbu || '.' || r.getc('x$prog')));
					if pv.protocol = 'HTTP' then
						k_debug.trace(st(r.client_addr, r.ua));
					end if;
					goto make_connection;
				end if;
			exception
				when utl_tcp.transfer_timeout then
					k_debug.trace(st('gateway find fin marker error, transfer_timeout',
													 pv.cfg_id,
													 r.dbu || '.' || r.getc('x$prog'),
													 v_time,
													 sysdate));
					if (sysdate - v_time) * 24 * 60 * 60 < 9 then
						goto check_end_of_req;
					else
						goto make_connection;
					end if;
				when utl_tcp.end_of_input then
					k_debug.trace(st('gateway find fin marker error, end_of_input',
													 pv.cfg_id,
													 r.dbu || '.' || r.getc('x$prog'),
													 v_time,
													 sysdate));
					if (sysdate - v_time) * 24 * 60 * 60 < 9 then
						goto check_end_of_req;
					else
						goto make_connection;
					end if;
				when utl_tcp.network_error then
					k_debug.trace(st('gateway find fin marker error, network_error', pv.cfg_id, r.dbu || '.' || r.getc('x$prog')));
					goto make_connection;
				when others then
					k_debug.trace(st('gateway find fin marker error, other', pv.cfg_id, r.dbu || '.' || r.getc('x$prog')));
					goto make_connection;
			end;
			v_dummy := utl_tcp.write_text(pv.c, '-- end of req --', 16);
			utl_tcp.flush(pv.c);
		
		end loop;
	
		<<the_end>>
		raise_application_error(-20526, '');
	
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
