create or replace package body framework is

	/* main functions
  0. establish connection to nodejs and listen for request
  1. (x) control lifetime by max requests and max runtime
  2. switch to target user current_schema
  3. collect request cpu/ellapsed time
  4. collect hprof statistics
  5. graceful quit, signal quit and accept quit control frame, then quit
  6. keep alive with dispatcher
  7. exit when ora-600 ora-7445 occurred
  */

	procedure entry
	(
		cfg_id  varchar2 := null,
		slot_id pls_integer := 1
	) is
		v_done    boolean := false;
		v_quit    boolean := false;
		v_qcode   pls_integer := -20526;
		v_clinfo  varchar2(64);
		v_timeout pls_integer := 3;
		v_maxwcnt pls_integer := 3;
		v_count   pls_integer;
		v_sts     number := -1;
		v_return  integer;
	
		v_svr_stime   date := sysdate;
		v_svr_req_cnt pls_integer := 0;
	
		v_cfg server_control_t%rowtype;
	
		-- private 
		procedure close_conn is
		begin
			if pv.c.remote_host is not null then
				utl_tcp.close_connection(pv.c);
				pv.c := null;
			end if;
		exception
			when utl_tcp.network_error then
				null;
			when others then
				k_debug.trace(st('close_conn_error', sqlcode, sqlerrm), 'keep_conn');
		end;
	
		-- private
		procedure make_conn is
			v_sid  pls_integer;
			v_seq  pls_integer;
			v_inst pls_integer;
			v_spid pls_integer;
			v_all  varchar2(200);
			v_raw4 raw(4);
			v_mno  pls_integer := 197610261;
			v_mnd  pls_integer := 197610262;
			function env(n varchar2) return varchar2 is
			begin
				return sys_context('USERENV', n);
			end;
			procedure wpi(i binary_integer) is
			begin
				pv.wlen := utl_tcp.write_raw(pv.c, utl_raw.cast_from_binary_integer(i));
			end;
		begin
			pv.c := utl_tcp.open_connection(v_cfg.gw_host,
																			v_cfg.gw_port,
																			charset         => null,
																			in_buffer_size  => 32767,
																			out_buffer_size => 0,
																			tx_timeout      => v_timeout);
			select s.sid, s.serial#, p.spid
				into v_sid, v_seq, v_spid
				from v$session s, v$process p
			 where s.paddr = p.addr
				 and s.sid = sys_context('userenv', 'sid');
			v_inst := nvl(env('INSTANCE'), -1);
			v_all  := env('DB_NAME') || '/' || env('DB_DOMAIN') || '/' || env('DB_UNIQUE_NAME') || '/' ||
								env('DATABASE_ROLE') || '/' || pv.cfg_id;
		
			wpi(v_mno);
			wpi(pv.in_seq * 256 * 256 + 0 * 256 + 0);
			wpi(lengthb(v_all) + 4 * 6);
			wpi(v_inst);
			wpi(v_sid);
			wpi(v_seq);
			wpi(v_spid);
			wpi(floor((sysdate - v_svr_stime) * 24 * 60));
			wpi(v_svr_req_cnt);
			-- wpi(nvl(v_cfg.idle_timeout, 0));
			pv.wlen := utl_tcp.write_text(pv.c, v_all);
			pv.wlen := utl_tcp.read_raw(pv.c, v_raw4, 4, false);
			v_mnd   := utl_raw.cast_to_binary_integer(v_raw4);
			dbms_output.put_line(v_mnd);
		end;
	
		function got_quit_signal return boolean is
		begin
			v_sts := dbms_pipe.receive_message(v_clinfo, 0);
			if v_sts not in (0, 1) then
				k_debug.trace(st(v_clinfo, 'got signal ' || v_sts), 'dispatcher');
			end if;
			return v_sts = 0;
		end;
	
		procedure signal_quit is
		begin
			-- only signal dispatcher to quit once
			if v_quit then
				return;
			end if;
			v_quit      := true;
			pv.cslot_id := 0;
			bios.write_frame(255);
		end;
	
		procedure do_quit is
		begin
			k_debug.trace(st(v_clinfo, 'call quit'), 'dispatcher');
			raise_application_error(v_qcode, '');
		end;
	
		procedure show_exception is
		begin
			k_debug.trace(st('system exception(url,cfg_id,sqlcode,sqlerrm,error_backtrace)',
											 r.url,
											 pv.cfg_id,
											 sqlcode,
											 sqlerrm,
											 dbms_utility.format_error_backtrace));
			h.status_line(500);
			h.content_type('text/plain');
			b.line(dbms_utility.format_error_stack);
		end;
	
	begin
		execute immediate 'alter session set nls_date_format="yyyy-mm-dd hh24:mi:ss"';
		if cfg_id is null then
			select a.job_name
				into v_clinfo
				from user_scheduler_running_jobs a
			 where a.session_id = sys_context('userenv', 'sid');
			pv.cfg_id := substr(v_clinfo, 9, lengthb(v_clinfo) - 8 - 5);
			pv.in_seq := to_number(substr(v_clinfo, -4));
		else
			pv.cfg_id := cfg_id;
			pv.in_seq := slot_id;
			v_clinfo  := 'Noradle-' || cfg_id || ':' || ltrim(to_char(slot_id, '0000'));
		end if;
	
		select count(*) into v_count from v$session a where a.client_info = v_clinfo;
		if v_count > 0 then
			dbms_output.put_line('Noradle Server Status:inuse. quit');
			return;
		end if;
		dbms_application_info.set_client_info(v_clinfo);
		dbms_application_info.set_module('free', null);
		dbms_pipe.purge(v_clinfo);
		k_cfg.server_control(v_cfg);
		pv.entry := 'framework.entry';
	
		<<make_connection>>
		dbms_application_info.set_module('utl_tcp', 'open_connection');
		loop
			begin
				close_conn;
				k_debug.trace(st(v_clinfo, 'try connect to dispatcher'), 'dispatcher');
				make_conn;
				exit;
				k_debug.trace(st(v_clinfo, 'connected to dispatcher'), 'dispatcher');
			exception
				when utl_tcp.network_error then
					if sysdate > v_svr_stime + v_cfg.max_lifetime then
						k_debug.trace(st(v_clinfo, 'max lifetime reached'), 'dispatcher');
						do_quit; -- quit immediately in disconnected state
					end if;
					if got_quit_signal then
						k_debug.trace(st(v_clinfo, 'quit signal received'), 'dispatcher');
						do_quit; -- quit immediately in disconnected state
					end if;
					pv.c := null;
					-- do not continuiously try connect to waste computing resource
					dbms_lock.sleep(1);
			end;
		end loop;
	
		loop
			dbms_application_info.set_module('utl_tcp', 'get_line');
			--k_debug.trace(st(v_clinfo, 'wait reqeust'), 'dispatcher');
		
			-- request quit when max requests reached
			v_svr_req_cnt := v_svr_req_cnt + 1;
			if v_svr_req_cnt > v_cfg.max_requests then
				k_debug.trace(st(v_clinfo, 'over max requests'), 'dispatcher');
				signal_quit;
			end if;
		
			v_count := 0;
			<<read_request>>
		
			-- request quit when max lifetime reached
			if sysdate > v_svr_stime + v_cfg.max_lifetime then
				k_debug.trace(st(v_clinfo, 'over max lifetime'), 'dispatcher');
				signal_quit;
			end if;
		
			-- request quit when quit pipe signal arrived
			if got_quit_signal then
				k_debug.trace(st(v_clinfo, 'got quit signal'), 'dispatcher');
				signal_quit;
			end if;
		
			-- accept arrival of new request
			begin
				v_count := v_count + 1;
				bios.read_request;
				pv.headers.delete;
				k_debug.time_header('after-read');
			exception
				when utl_tcp.transfer_timeout then
					if v_count > v_maxwcnt then
						-- after keep-alive time, no data arrived, think it as lost connection
						k_debug.trace(st(v_clinfo, 'over idle timeout'), 'dispatcher');
						do_quit;
					else
						goto read_request;
					end if;
				when utl_tcp.end_of_input then
					k_debug.trace(st(v_clinfo, 'end of tcp'), 'dispatcher');
					do_quit;
			end;
		
			if pv.cslot_id = 0 then
				case pv.protocol
					when 'QUIT' then
						k_debug.trace(st(v_clinfo, 'signaled QUIT'), 'dispatcher');
						do_quit;
					when 'KEEPALIVE' then
						v_maxwcnt := floor(r.getn('keepAliveInterval', 60) + 3 / v_timeout);
						k_debug.trace(st(v_clinfo, 'signaled KEEPALIVE', v_maxwcnt), 'dispatcher');
						v_count := 0;
						continue;
					when 'ASK_OSP' then
						dbms_pipe.pack_message('ASK_OSP');
						dbms_pipe.pack_message(pv.cfg_id);
						dbms_pipe.pack_message(r.getn('queue_len'));
						dbms_pipe.pack_message(r.getn('oslot_cnt'));
						v_return := dbms_pipe.send_message('Noradle-PMON');
						continue;
					else
						continue;
				end case;
			end if;
		
			if pv.hp_flag then
				dbms_hprof.start_profiling('PLSHPROF_DIR', v_clinfo || '.trc');
				pv.hp_label := '';
			end if;
		
			-- read & parse request info and do init work
			pv.firstpg := true;
			begin
				case pv.protocol
					when 'HTTP' then
						-- as http, http2, fast-cgi, spdy
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
					do_quit;
				when others then
					k_debug.trace(st('page before exection',
													 pv.protocol,
													 r.url,
													 sqlcode,
													 sqlerrm,
													 dbms_utility.format_error_backtrace));
					do_quit;
			end;
			pv.firstpg := false;
			-- do all pv init beforehand, next call to page init will not be first page
			k_mapping.set;
		
			-- this is for become user
			v_done := false;
			if substrb(r.getc('x$prog'), -2) in ('_t', '_v') then
				r.setc('x$prog', 'k_sql.get');
			end if;
			r."_after_map";
			dbms_application_info.set_module(r.dbu || '.' || nvl(r.pack, r.proc), t.tf(r.pack is null, 'standalone', r.proc));
		
			k_debug.time_header('before-exec');
			<<re_call_servlet>>
			declare
				no_dad_db_user exception; -- servlet db user does not exist
				pragma exception_init(no_dad_db_user, -1435);
				no_dad_auth_entry1 exception; -- table or view does not exist
				pragma exception_init(no_dad_auth_entry1, -942);
				no_dad_auth_entry2 exception;
				pragma exception_init(no_dad_auth_entry2, -6576);
				no_dad_auth_entry_right exception; -- table or view does not exist
				pragma exception_init(no_dad_auth_entry_right, -01031);
				ora_600 exception; -- oracle internal error
				pragma exception_init(ora_600, -600);
				ora_7445 exception; -- oracle internal error
				pragma exception_init(ora_600, -7445);
			begin
				execute immediate 'call ' || r.dbu || '.dad_auth_entry()';
			exception
				when no_dad_auth_entry1 or no_dad_auth_entry2 or no_dad_auth_entry_right then
					if v_done then
						show_exception;
					else
						begin
							sys.pw.add_dad_auth_entry(r.dbu);
							v_done := true;
							goto re_call_servlet;
						exception
							when no_dad_db_user then
								show_exception;
						end;
					end if;
				when ora_600 or ora_7445 then
					-- todo: tell dispatcher unrecoverable error occured, and then quit
					-- todo: give all request info back to dispatcher to resend to another OSP
					-- todo: or dispatcher keep request info, prepare to resend to another OSP
					show_exception;
					do_quit;
				when others then
					-- system(not app level at k_gw) exception occurred        
					show_exception;
			end;
		
			output.finish;
			bios.write_session;
			bios.write_end;
			utl_tcp.flush(pv.c);
		
			if pv.hp_flag then
				dbms_hprof.stop_profiling;
				tmp.s := nvl(pv.hp_label, 'noradle://' || r.dbu || '/' || r.prog);
				tmp.n := dbms_hprof.analyze('PLSHPROF_DIR', v_clinfo || '.trc', run_comment => tmp.s);
			end if;
		
		end loop;
	
	exception
		when others then
			-- all quit will go here, normal quit or exception, to allow sqlplus based OPS
			utl_tcp.close_all_connections;
			if v_sts = 0 then
				dbms_output.put_line('Noradle Server Status:kill.');
			else
				dbms_output.put_line('Noradle Server Status:restart.');
			end if;
			if sqlcode != v_qcode then
				k_debug.trace(st('gateway listen exception', pv.cfg_id, sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
			end if;
	end;

end framework;
/
