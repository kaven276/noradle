create or replace package body k_pmon is

	procedure start_one_server_process(no pls_integer) is
	begin
		dbms_scheduler.create_job('"PSP.WEB_' || ltrim(to_char(no, '0000')) || '"',
															job_type => 'STORED_PROCEDURE',
															job_action => 'gateway.listen',
															start_date => sysdate,
															enabled => true,
															auto_drop => true);
	end;

	procedure once is
		v_cnt pls_integer := k_cfg.server_control().min_servers;
	begin
		for i in (select rownum no
								from dual
							connect by rownum <= v_cnt
							minus
							select to_number(substrb(a.job_name, 9)) from user_scheduler_jobs a where a.job_action = 'gateway.listen') loop
			start_one_server_process(i.no);
		end loop;
	end;

	procedure daemon is
		v_msg varchar2(100);
		v_sts number;
	begin
		once;
		dbms_alert.register('PW_STOP_SERVER');
		loop
			if v_status = 0 then
				dbms_alert.remove('PW_STOP_SERVER');
				-- stop all server jobs
				return;
			end if;
			once;
		end loop;
	end;

	procedure create_deamon_job is
	begin
		dbms_scheduler.create_job('"PSP.WEB_PMON"',
															job_type        => 'STORED_PROCEDURE',
															job_action      => 'k_pmon.daemon',
															enabled         => true,
															auto_drop       => true);
	end;

	procedure stop is
	begin
		dbms_alert.signal('PW_STOP_SERVER', null);
		commit;
	end;

	procedure create_deamon_job_unstable is
	begin
		dbms_scheduler.create_job('"PSP.WEB_PMON"',
															job_type        => 'STORED_PROCEDURE',
															job_action      => 'k_pmon.once',
															start_date      => sysdate,
															repeat_interval => 'FREQ=SECONDLY;PERIODS=10',
															enabled         => true,
															auto_drop       => false);
	end;

end k_pmon;
/
