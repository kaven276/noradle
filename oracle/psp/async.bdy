create or replace package body async is

	-- Refactored procedure quit
	function get_alert_quit(p_stop varchar2) return boolean is
		v_msg varchar2(1);
		v_sts number;
	begin
		dbms_alert.waitone(p_stop, v_msg, v_sts, 0);
		if v_sts = 0 then
			dbms_alert.remove(p_stop);
			return true;
		else
			return false;
		end if;
	end;

	procedure listen
	(
		p_pipe_name varchar2,
		p_slot      number
	) is
		v_cfg   async_control_t%rowtype;
		v_dbu   varchar2(30);
		v_stime date := sysdate;
		v_etime date;
		v_count number(9) := 0;
		v_stop  varchar2(30) := p_pipe_name || '#' || p_slot;
	
		no_dad_auth_entry1 exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry1, -942);
		no_dad_auth_entry2 exception;
		pragma exception_init(no_dad_auth_entry2, -6576);
		no_dad_auth_entry_right exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry_right, -01031);
		v_done boolean := false;
	begin
		dbms_alert.register(v_stop);
		-- listen to the pipe name
		-- then dynamic execute target procedure
		select a.* into v_cfg from async_control_t a where a.pipe_name = p_pipe_name;
		v_cfg.max_requests := nvl(v_cfg.max_requests, 999999999);
		v_etime            := v_stime + v_cfg.max_lifetime;
		loop
			if get_alert_quit(v_stop) then
				exit;
			end if;
			tmp.k := dbms_pipe.receive_message(p_pipe_name, 3);
			if tmp.k = 1 then
				if sysdate > v_etime then
					exit;
				end if;
				continue; -- timeout;
			end if;
		
			if v_cfg.dbu is null then
				dbms_pipe.unpack_message(v_dbu);
			else
				v_dbu := v_cfg.dbu;
			end if;
		
			-- this is for become user
			<<redo>>
			begin
				execute immediate 'call ' || v_dbu || '.async_auth_entry(:1)'
					using v_cfg.prog;
			exception
				when no_dad_auth_entry1 or no_dad_auth_entry2 or no_dad_auth_entry_right then
					if v_done then
						raise;
					end if;
					sys.pw.add_async_auth_entry(v_dbu);
					v_done := true;
					goto redo;
				when others then
					k_debug.trace(st('job exception', v_dbu, sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
					exit;
			end;
		
			v_count := v_count + 1;
			if v_count > v_cfg.max_requests then
				exit;
			end if;
		
		end loop;
	end;

	procedure start_one_job
	(
		p_pipe_name varchar2,
		p_slot      number
	) is
		v_job_name varchar2(30) := p_pipe_name || '#' || p_slot;
	begin
		dbms_output.put_line(v_job_name);
		dbms_scheduler.create_job(job_name            => v_job_name,
															job_type            => 'STORED_PROCEDURE',
															job_action          => 'async.listen',
															number_of_arguments => 2,
															job_class           => 'DEFAULT_JOB_CLASS',
															enabled             => false,
															auto_drop           => true,
															start_date          => sysdate,
															comments            => 'async managed');
		dbms_scheduler.set_job_argument_value(v_job_name, 1, p_pipe_name);
		dbms_scheduler.set_job_argument_value(v_job_name, 2, to_char(p_slot));
		dbms_scheduler.enable(name => v_job_name);
	end;

	procedure adjust is
		v_job varchar2(30);
	begin
		for cfg in (select a.* from async_control_t a) loop
			v_job := cfg.pipe_name || '#';
		
			for i in (select to_number(substrb(a.job_name, -1)) slot
									from user_scheduler_jobs a
								 where a.job_name like v_job || '%') loop
				if i.slot > cfg.min_servers then
					dbms_alert.signal(cfg.pipe_name || '#' || i.slot, null);
				end if;
			end loop;
			commit;
		
			for i in (select rownum slot
									from dual
								 where rownum <= cfg.min_servers
								connect by rownum <= cfg.min_servers
								minus
								select to_number(substrb(a.job_name, -1)) slot
									from user_scheduler_jobs a
								 where a.job_name like v_job || '%') loop
				start_one_job(cfg.pipe_name, i.slot);
			end loop;
		end loop;
	end;

	procedure stop(p_pipe_name varchar2) is
	begin
		for cfg in (select a.* from async_control_t a where a.pipe_name = p_pipe_name) loop
			for i in 1 .. cfg.min_servers loop
				dbms_alert.signal(cfg.pipe_name || '#' || i, null);
				-- dbms_scheduler.drop_job(cfg.pipe_name || '#' || i);
			end loop;
		end loop;
		commit;
	end;

	procedure stop_all is
	begin
		for cfg in (select a.* from async_control_t a) loop
			for i in 1 .. cfg.min_servers loop
				dbms_alert.signal(cfg.pipe_name || '#' || i, null);
				-- dbms_scheduler.drop_job(cfg.pipe_name || '#' || i);
			end loop;
		end loop;
		commit;
	end;

	procedure monitor is
	begin
		dbms_scheduler.create_job(job_name            => 'ASYNC_MON',
															job_type            => 'STORED_PROCEDURE',
															job_action          => 'async.adjust',
															number_of_arguments => 0,
															job_class           => 'DEFAULT_JOB_CLASS',
															enabled             => true,
															auto_drop           => true,
															repeat_interval     => 'Freq=Minutely',
															comments            => 'async monitor');
	end;
end async;
/
