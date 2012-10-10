create or replace package body k_dco_adm is

	procedure signal_reconnect
	(
		host varchar2,
		port number
	) is
	begin
		dbms_alert.signal('Noradle-DCO-EXTHUB-QUIT', host || ':' || port);
		commit;
	end;

	procedure wait_reconnect_exthub
	(
		host   varchar2,
		port   number,
		unused boolean := false
	) is
		v_resp   varchar2(20);
		v_errmsg varchar2(100) := 'can not signal ext-hub to exit';
	begin
		dcopv.con := utl_tcp.open_connection(remote_host     => host,
																				 remote_port     => port,
																				 charset         => null,
																				 in_buffer_size  => 32767,
																				 out_buffer_size => 0,
																				 tx_timeout      => 0);
	
		dcopv.tmp_pi := utl_tcp.write_raw(dcopv.con, hextoraw('0000000000000000ffffffff'));
	
		if utl_tcp.available(dcopv.con, 3) <= 0 then
			raise_application_error(-20000, v_errmsg);
		end if;
		dcopv.tmp_pi := utl_tcp.read_line(dcopv.con, v_resp, true);
		if v_resp = 'exiting' then
			utl_tcp.close_connection(dcopv.con);
			dbms_alert.signal('Noradle-DCO-EXTHUB-QUIT', '');
			commit;
		else
			raise_application_error(-20001, v_errmsg);
		end if;
		if unused then
			update exthub_config_t a
				 set a.sts = null
			 where a.host = wait_reconnect_exthub.host
				 and a.port = wait_reconnect_exthub.port;
			commit;
		end if;
	end;

end k_dco_adm;
/
