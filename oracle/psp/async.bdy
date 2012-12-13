create or replace package body async is

	procedure listen(p_pipe_name varchar2) is
		v_cfg   async_control_t%rowtype;
		v_dbu   varchar2(30);
		v_stime date := sysdate;
		v_etime date;
		v_count number(9) := 0;
	
		no_dad_auth_entry1 exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry1, -942);
		no_dad_auth_entry2 exception;
		pragma exception_init(no_dad_auth_entry2, -6576);
		no_dad_auth_entry_right exception; -- table or view does not exist
		pragma exception_init(no_dad_auth_entry_right, -01031);
		v_done boolean := false;
	begin
		-- listen to the pipe name
		-- then dynamic execute target procedure
		select a.* into v_cfg from async_control_t a where a.pipe_name = p_pipe_name;
		v_cfg.max_requests := nvl(v_cfg.max_requests, 999999999);
		v_etime            := v_stime + v_cfg.max_lifetime;
		loop
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
					k_debug.trace(st('page exception', v_dbu, sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
					exit;
			end;
		
			v_count := v_count + 1;
			if v_count > v_cfg.max_requests then
				exit;
			end if;
		
		end loop;
	end;

end async;
/
