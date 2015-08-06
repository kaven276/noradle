create or replace package body k_pmon is

	type num_arr is table of server_control_t.cfg_id%type index by varchar2(100);
	gv_quota num_arr;
	gv_inc   boolean := false;

	function job_prefix(cfg varchar2) return varchar2 deterministic is
	begin
		return 'Noradle-' ||(cfg) || ':';
	end;

	procedure start_one_server_process
	(
		cfg varchar2,
		no  pls_integer,
		ent varchar2
	) is
	begin
		dbms_scheduler.create_job('"' || job_prefix(cfg) || ltrim(to_char(no, '0000')) || '"',
															job_type => 'STORED_PROCEDURE',
															job_action => ent,
															start_date => sysdate,
															enabled => true,
															auto_drop => true);
	end;

	procedure adjust is
		v_prefix varchar2(30);
		v_quota  server_control_t.min_servers%type;
		v_free   server_control_t.min_servers%type;
	begin
		for c in (select a.* from server_control_t a where a.disabled is null) loop
			v_prefix := job_prefix(c.cfg_id);
			if not gv_quota.exists(c.cfg_id) then
				gv_quota(c.cfg_id) := c.min_servers;
			end if;
			v_quota := gv_quota(c.cfg_id);
			if gv_inc then
				gv_inc := false;
			elsif v_quota > c.min_servers then
				select count(*)
					into v_free
					from v$session a
				 where a.status = 'ACTIVE'
					 and a.client_info like 'Noradle-' || c.cfg_id || ':%'
					 and (a.module = 'utl_tcp' and a.action = 'get_line');
				v_quota := v_quota - floor(v_free / 2);
			end if;
			if v_quota < c.min_servers then
				v_quota := c.min_servers;
			elsif v_quota > c.max_servers then
				v_quota := c.max_servers;
			end if;
			gv_quota(c.cfg_id) := v_quota;
			for i in (select rownum no
									from dual
								 where rownum <= v_quota
								connect by rownum <= v_quota
								minus
								select to_number(substrb(a.job_name, -4))
									from user_scheduler_jobs a
								 where a.job_action = 'framework.entry'
									 and a.job_name like v_prefix || '%') loop
				k_debug.trace(st('k_pmon.adjust', c.cfg_id, i.no), 'dispatcher');
				start_one_server_process(c.cfg_id, i.no, 'framework.entry');
			end loop;
			kill(c.cfg_id, keep => v_quota);
		end loop;
		for c in (select a.* from server_control_t a where a.disabled is not null) loop
			kill(c.cfg_id);
		end loop;
	end;

	procedure inc_quota is
		v_cfg_id    server_control_t.cfg_id%type;
		v_queue_len pls_integer;
		v_oslot_cnt pls_integer;
	begin
		dbms_pipe.unpack_message(v_cfg_id);
		dbms_pipe.unpack_message(v_queue_len);
		dbms_pipe.unpack_message(v_oslot_cnt);
		gv_quota(v_cfg_id) := v_queue_len + v_oslot_cnt;
		gv_inc := true;
	exception
		when no_data_found then
			null;
	end;

	function got_signal return boolean is
		v_sts  number := -1;
		v_type varchar2(100);
	begin
		v_sts := dbms_pipe.receive_message('Noradle-PMON', 10);
		if v_sts != 0 then
			return false;
		end if;
		dbms_pipe.unpack_message(v_type);
		case v_type
			when 'SIGKILL' then
				return true;
			when 'ASK_OSP' then
				inc_quota;
				return false;
		end case;
	end;

	procedure run is
		v_msg varchar2(100);
		v_sts number;
	begin
		for i in (select a.cfg_id, a.min_servers from server_control_t a) loop
			gv_quota(i.cfg_id) := i.min_servers;
		end loop;
		dbms_pipe.purge('Noradle-PMON');
		adjust;
		loop
			exit when got_signal;
			adjust;
		end loop;
	exception
		when others then
			k_debug.trace(sqlerrm);
	end;

	procedure run_job is
	begin
		if user != 'SYS' and user != sys_context('userenv', 'current_schema') then
			raise_application_error(-20000, 'only psp user can start noradle service.');
		end if;
		dbms_scheduler.create_job('"PSP.WEB_PMON"',
															job_type        => 'STORED_PROCEDURE',
															job_action      => 'k_pmon.run',
															enabled         => true,
															auto_drop       => true);
	end;

	procedure stop is
		v_return integer;
	begin
		dbms_pipe.pack_message('SIGKILL');
		v_return := dbms_pipe.send_message('Noradle-PMON');
		kill;
	end;

	procedure rerun_job is
	begin
		k_pmon.stop;
		dbms_lock.sleep(3);
		k_pmon.run_job;
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
