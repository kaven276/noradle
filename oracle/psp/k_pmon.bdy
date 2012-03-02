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

	procedure adjust is
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

	procedure run is
		v_msg varchar2(100);
		v_sts number;
	begin
		adjust;
		dbms_alert.register('PW_STOP_SERVER');
		loop
			dbms_alert.waitone('PW_STOP_SERVER', v_msg, v_sts, 10);
			if v_sts = 1 then
				adjust;
				continue;
			end if;
			dbms_alert.remove('PW_STOP_SERVER');
			for i in (select a.job_name
									from user_scheduler_jobs a
								 where a.job_action = 'gateway.listen'
									 and a.state != 'RUNNING') loop
				dbms_scheduler.drop_job('"' || i.job_name || '"');
			end loop;
			dbms_alert.signal('PW_STOP_SERVER', ''); -- stop newly created server job
			commit;
			return;
		end loop;
	end;

	procedure run_job is
	begin
		dbms_scheduler.create_job('"PSP.WEB_PMON"',
															job_type        => 'STORED_PROCEDURE',
															job_action      => 'k_pmon.run',
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
															job_action      => 'k_pmon.adjust',
															start_date      => sysdate,
															repeat_interval => 'FREQ=SECONDLY;PERIODS=10',
															enabled         => true,
															auto_drop       => false);
	end;

end k_pmon;
/
