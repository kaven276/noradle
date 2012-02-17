create or replace package body gateway is

	procedure error_not_bch is
	begin
		h.status_line(403);
		h.content_type;
		h.header_close;
		p.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
		output.finish;
	end;

	(
	) is
	begin
		h.status_line(500);
	end;

	procedure listen is
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
			pv.csslink         := null;
			pv.allow           := null;
		
			r."_init"(pv.c, 80526);
			h.content_type;
			output."_init"(80526);
			-- k_xhtp.init;
		
			if substrb(nvl(r.pack, r.proc), -2) not in ('_c', '_b', '_h') then
				error_not_bch;
				continue;
			end if;
		
			begin
			exception
				when others then
			end;
			output.finish;
		
		end loop;
	end;

begin
	dbms_lob.createtemporary(pv.entity, cache => true, dur => dbms_lob.session);
	dbms_lob.createtemporary(pv.gzip_entity, cache => true, dur => dbms_lob.session);
	dbms_lob.createtemporary(pv.csstext, cache => true, dur => dbms_lob.session);
	pv.write_buff_size := dbms_lob.getchunksize(pv.entity);

end gateway;
/
