create or replace package body k_pmon is

	function job_prefix(cfg varchar2) return varchar2 deterministic is
	begin
		return 'PSP.WEB_' || upper(cfg) || ':';
	end;

	procedure start_one_server_process
	(
		cfg varchar2,
		no  pls_integer
	) is
	begin
		dbms_scheduler.create_job('"' || job_prefix(cfg) || ltrim(to_char(no, '0000')) || '"',
															job_type => 'STORED_PROCEDURE',
															job_action => 'gateway.listen',
															start_date => sysdate,
															enabled => true,
															auto_drop => true);
	end;

	procedure adjust is
		v_prefix varchar2(30);
	begin
		for c in (select * from server_control_t) loop
			v_prefix := job_prefix(c.cfg_id);
			for i in (select rownum no
									from dual
								 where rownum <= c.min_servers
								connect by rownum <= c.min_servers
								minus
								select to_number(substrb(a.job_name, -4))
									from user_scheduler_jobs a
								 where a.job_action = 'gateway.listen'
									 and a.job_name like v_prefix || '%') loop
				start_one_server_process(c.cfg_id, i.no);
			end loop;
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
								 where a.job_action = 'gateway.listen' -- and a.state != 'RUNNING'
								) loop
				dbms_scheduler.drop_job('"' || i.job_name || '"');
			end loop;
			dbms_alert.signal('PW_STOP_SERVER', ''); -- stop newly created server job
			commit;
			return;
		end loop;
	end;

	procedure run_job is
	begin
		if user != sys_context('userenv', 'current_schema') then
			raise_application_error(-20000, '必须以psp用户登录才能启动Noradle服务');
		end if;
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
