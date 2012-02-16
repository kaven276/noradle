create or replace package body gateway is

	procedure error_not_bch is
	begin
		h.status_line(403);
		h.content_type;
		h.header_close;
		p.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
		output.finish;
	end;

	procedure error_not_exist is
	begin
		h.status_line(404);
		h.content_type;
		h.header_close;
		p.line('The program unit "' || r.prog || '" is not exist');
	end;

	procedure error_execute
	(
		ecode varchar2,
		emsg  varchar2
	) is
	begin
		h.status_line(500);
		h.content_type('text/plain');
		h.header_close;
		p.init;
		p.http_header_close;
		p.line('The program unit "' || r.prog || '" is executed with error');
		p.line('[sqlcode]');
		p.line(ecode);
		p.line('[sqlerrm]');
		p.line(emsg);
	end;

	procedure listen is
		v_sql varchar2(100);
		v_len pls_integer;
		ex_no_prog exception;
		pragma exception_init(ex_no_prog, -6576);
	begin
		<<make_connection>>
		begin
			pv.c := utl_tcp.open_connection(remote_host     => '192.168.177.1',
																			remote_port     => 1522,
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
			pv.allow           := null;
		
			r."_init"(pv.c, 80526);
			h.content_type;
			output."_init"(80526);
			-- k_xhtp.init;
		
			if substrb(nvl(r.pack, r.proc), -2) not in ('_c', '_b', '_h') then
				error_not_bch;
				continue;
			end if;
		
			v_sql := 'call ' || r.prog || '()';
			begin
				execute immediate v_sql;
				commit;
			exception
				when ex_no_prog then
					error_not_exist;
				when gateway.ex_resp_done then
					commit;
				when others then
					error_execute(sqlcode, sqlerrm);
			end;
			output.finish;
		
		end loop;
	end;

begin
	dbms_lob.createtemporary(pv.entity, cache => true, dur => dbms_lob.session);
	pv.write_buff_size := dbms_lob.getchunksize(pv.entity);
	dbms_lob.createtemporary(pv.csstext, cache => true, dur => dbms_lob.session);

end gateway;
/
