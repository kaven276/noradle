create or replace package body gateway is

	procedure error_not_bch is
	begin
		h.allow_get_post;
		h.status_line(403);
		h.content_type('text/plain');
		h.header_close;
		h.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
		output.finish;
	end;

	procedure error_dad_auth_entry
	(
		code number,
		errm varchar2
	) is
	begin
		h.allow_get_post;
		h.status_line(500);
		h.content_type('text/plain');
		h.header_close;
		h.line('in servlet occurred dyna sp call error for dbu : ' || r.dbu);
		h.line('error text = ' || code || '/' || errm);
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

	procedure listen is
		no_dad_auth_entry1 exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry1, -942);
		no_dad_auth_entry2 exception;
		pragma exception_init(no_dad_auth_entry2, -6576);
		no_dad_auth_entry_right exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry_right, -01031);
		v_done boolean := false;
	begin
		select substr(a.job_name, 9, lengthb(a.job_name) - 8 - 5)
			into pv.cur_cfg_id
			from user_scheduler_running_jobs a
		 where a.session_id = sys_context('userenv', 'sid');
		k_debug.trace(st(sys_context('USERENV', 'SID'), pv.cur_cfg_id), 'bgjobid');
	
		dbms_alert.register('PW_STOP_SERVER');
		pv.svr_request_count := 0;
		pv.svr_start_time    := sysdate;
		<<make_connection>>
		begin
			pv.c := utl_tcp.open_connection(remote_host     => k_cfg.server_control().gw_host,
																			remote_port     => k_cfg.server_control().gw_port,
																			charset         => null,
																			in_buffer_size  => pv.write_buff_size,
																			out_buffer_size => 0,
																			tx_timeout      => 3);
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
		
			if sysdate > pv.svr_start_time + k_cfg.server_control().max_lifetime then
				goto the_end;
			end if;
		
			if quit then
				goto the_end;
			end if;
		
			begin
				pv.end_marker := utl_tcp.get_line(pv.c, true);
			exception
				when utl_tcp.transfer_timeout then
					goto read_request;
				when utl_tcp.end_of_input then
					goto make_connection;
				when utl_tcp.network_error then
					return;
					goto make_connection;
			end;
		
			case pv.end_marker
				when 'quit_process' then
					return;
				when 'feedback' then
					output.write_head;
					utl_tcp.flush(pv.c);
					output.do_write(pv.buffered_length, false);
					continue;
				when 'csslink' then
					output.do_css_write;
					continue;
				when 'NodeJS Call' then
					pv.call_type := 1;
				else
					pv.call_type := 0; -- normal process
			end case;
		
			pv.elpt := dbms_utility.get_time;
			pv.cput := dbms_utility.get_cpu_time;
		
			-- initialize package variables
			v_done := false;
			pv.headers.delete;
			pv.cookies.delete;
			pv.header_writen   := false;
			pv.allow_content   := false;
			pv.buffered_length := 0;
			pv.max_lmt         := null;
			pv.msg_stream      := false;
			pv.use_stream      := false;
			pv.gzip            := null;
			pv.content_md5     := null;
			pv.etag_md5        := null;
			pv.csslink         := null;
			pv.allow           := null;
			pv.nlbr            := chr(10);
		
			rb.charset_http := null;
			rb.charset_db   := null;
			rb.blob_entity  := null;
			rb.clob_entity  := null;
			rb.nclob_entity := null;
		
			r."_init"(pv.c, 80526);
			pv.status_code := 200;
			if pv.call_type = 0 then
				h.content_type;
			else
				h.content_type(h.mime_text, 'UTF-8');
			end if;
			output."_init"(80526);
			p.init;
		
			if substrb(nvl(r.pack, r.proc), -2) not in ('_c', '_b', '_h') then
				error_not_bch;
				continue;
			end if;
		
			if r.method = 'GET' then
				k_http.auto_chunk_max_size;
				k_http.auto_chunk_max_idle;
			end if;
		
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
				goto the_end; -- when stream quit, quit process also, to release resource
			end if;
			output.finish;
			pv.svr_request_count := pv.svr_request_count + 1;
			if pv.svr_request_count >= k_cfg.server_control().max_requests then
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
