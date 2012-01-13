create or replace package body gateway is

	c             utl_tcp.connection; -- TCP/IP connection to the Web server
	gv_end_marker varchar2(100);

	-- private
	procedure end_req is
		dummy pls_integer;
	begin
		-- will add missing </body></html> automatically
		dummy := utl_tcp.write_line(c, gv_end_marker);
		utl_tcp.flush(c);
	end;

	procedure listen is
		ret_val pls_integer;
		line    varchar2(1000);
		pos     pls_integer;
	
		v_sql varchar2(100);
	
	begin
		<<make_connection>>
		begin
			c := utl_tcp.open_connection(remote_host     => '192.168.177.1',
																	 remote_port     => 1522,
																	 charset         => 'utf8',
																	 in_buffer_size  => 32767,
																	 out_buffer_size => gc_buff_size,
																	 tx_timeout      => 10);
		exception
			when utl_tcp.network_error then
				dbms_lock.sleep(3);
				goto make_connection;
		end;
	
		loop
			<<read_request>>
			begin
				gv_end_marker := utl_tcp.get_line(c, true);
			exception
				when utl_tcp.transfer_timeout then
					goto read_request;
				when utl_tcp.end_of_input then
					goto make_connection;
				when utl_tcp.network_error then
					goto make_connection;
			end;
		
			if gv_end_marker = 'quit_process' then
				return;
			end if;
		
			r."_init"(c, 80526);
			p."_init"(c, 80526);
		
			v_sql := 'call ' || r.prog || '()';
			execute immediate v_sql;
			end_req;
		end loop;
	end;
end gateway;
/

