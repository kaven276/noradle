create or replace package body k_pmon is

	procedure start_server(no pls_integer) is
	begin
		dbms_scheduler.create_job('"PSP.WEB_' || ltrim(to_char(no, '0000')) || '"',
															job_type => 'STORED_PROCEDURE',
															job_action => 'gateway.listen',
															start_date => sysdate,
															enabled => true,
															auto_drop => true);
	end;

	procedure do is
		v_cnt pls_integer := k_cfg.server_control().min_servers;
	begin
		for i in (select rownum no
								from dual
							connect by rownum <= v_cnt
							minus
							select to_number(substrb(a.job_name, 9)) from user_scheduler_jobs a where a.job_action = 'gateway.listen') loop
			start_server(i.no);
		end loop;
	end;

end k_pmon;
/
