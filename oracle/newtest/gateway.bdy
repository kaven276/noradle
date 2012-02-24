create or replace package body gateway is

	procedure error_not_bch is
	begin
		h.status_line(403);
		h.content_type;
		h.header_close;
		p.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
		output.finish;
	end;

	procedure error_dad_auth_entry
	(
		code number,
		errm varchar2
	) is
	begin
		h.status_line(500);
		h.content_type('text/plain');
		p.line('in servlet occurred dyna sp call error for dbu : ' || r.dbu);
		p.line('error text = ' || code || '/' || errm);
	end;

	procedure listen is
		no_dad_auth_entry1 exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry1, -942);
		no_dad_auth_entry2 exception;
		pragma exception_init(no_dad_auth_entry2, -6576);
		v_done boolean := false;
	begin
		dbms_alert.register('PW_STOP_SERVER');
		pv.svr_request_count := 0;
		pv.svr_start_time    := sysdate;
		<<make_connection>>
		begin
			pv.c := utl_tcp.open_connection(remote_host     => k_cfg.server_control().gw_host,
																			remote_port     => k_cfg.server_control().gw_port,
																			charset         => null,
																			in_buffer_size  => pv.write_buff_size,
																			out_buffer_size => pv.write_buff_size,
																			tx_timeout      => 3);
		exception
			when utl_tcp.network_error then
				dbms_lock.sleep(3);
				goto make_connection;
		end;
	
		loop
			<<read_request>>
		
			if sysdate > pv.svr_start_time + k_cfg.server_control().max_lifetime then
				goto the_end;
			end if;
		
			declare
				v_msg varchar2(1);
				v_sts number;
			begin
				dbms_alert.waitone('PW_STOP_SERVER', v_msg, v_sts, 0);
				if v_sts = 0 then
					dbms_alert.remove('PW_STOP_SERVER');
					goto the_end;
				end if;
			end;
		
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
					output.do_write(pv.buffered_length, false);
					continue;
				when 'csslink' then
					output.do_css_write;
					continue;
				else
					null; -- normal process
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
			pv.use_stream      := false;
			pv.gzip            := null;
			pv.content_md5     := null;
			pv.etag_md5        := null;
			pv.csslink         := null;
			pv.allow           := null;
		
			rb.charset_http := null;
			rb.charset_db   := null;
			rb.blob_entity  := null;
			rb.clob_entity  := null;
			rb.nclob_entity := null;
		
			r."_init"(pv.c, 80526);
			pv.status_code := 200;
			h.content_type;
			output."_init"(80526);
			-- k_xhtp.init;
		
			if substrb(nvl(r.pack, r.proc), -2) not in ('_c', '_b', '_h') then
				error_not_bch;
				continue;
			end if;
		
			-- this is for become user
			<<redo>>
			begin
				execute immediate 'call ' || r.dbu || '.dad_auth_entry()';
			exception
				when no_dad_auth_entry1 or no_dad_auth_entry2 then
					if v_done then
						raise;
					end if;
					sys.pw.add_dad_auth_entry(r.dbu);
					v_done := true;
					goto redo;
				when others then
					error_dad_auth_entry(sqlcode, sqlerrm);
			end;
		
			output.finish;
			pv.svr_request_count := pv.svr_request_count + 1;
			if pv.svr_request_count >= k_cfg.server_control().max_requests then
				goto the_end;
			end if;
		
		end loop;
	
		<<the_end>>
		utl_tcp.close_all_connections;
	end;

begin
	dbms_lob.createtemporary(pv.entity, cache => true, dur => dbms_lob.session);
	dbms_lob.createtemporary(pv.gzip_entity, cache => true, dur => dbms_lob.session);
	dbms_lob.createtemporary(pv.csstext, cache => true, dur => dbms_lob.session);
	pv.write_buff_size := dbms_lob.getchunksize(pv.entity);

end gateway;
/
