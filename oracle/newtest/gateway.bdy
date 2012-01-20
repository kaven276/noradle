create or replace package body gateway is

	procedure listen is
		v_sql varchar2(100);
		v_len pls_integer;
	begin
		<<make_connection>>
		begin
			pv.c := utl_tcp.open_connection(remote_host     => '192.168.177.1',
																			remote_port     => 1522,
																			charset         => null, -- 'AL32UTF8',
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
		
			if pv.end_marker = 'quit_process' then
				return;
			end if;
		
			pv.elpt := dbms_utility.get_time;
			pv.cput := dbms_utility.get_cpu_time;
		
			r."_init"(pv.c, 80526);
			p."_init"(80526);
			pv.headers.delete;
			pv.header_writen := false;
			pv.allow_content := false;
			pv.use_stream    := false;
		
			v_sql := 'call ' || r.prog || '()';
			execute immediate v_sql;
			commit;
			p.finish;
		
			if not pv.headers.exists('Content-Length') then
				v_len := utl_tcp.write_line(pv.c, pv.end_marker);
				utl_tcp.flush(pv.c);
			end if;
		
		end loop;
	end;

begin
	dbms_lob.createtemporary(pv.entity, cache => true, dur => dbms_lob.session);
	pv.write_buff_size := dbms_lob.getchunksize(pv.entity);
end gateway;
/
