create or replace procedure servlet(name_array owa.vc_arr, value_array owa.vc_arr) authid current_user is
	no_dad_auth_entry1 exception; -- table or view does not exist
	pragma exception_init(no_dad_auth_entry1, -942);
	no_dad_auth_entry2 exception;
	pragma exception_init(no_dad_auth_entry2, -6576);
	v_done boolean := false;
	v_elpt number := dbms_utility.get_time;
	v_cput number := dbms_utility.get_cpu_time;
begin
	r.init(name_array, value_array);

	if r.prog is not null then
		-- execute immediate 'alter session set nls_lang="SIMPLIFIED CHINESE_CHINA.ZHS16GBK"';
		-- 注：此模式只适用于 location 中能得到 dad_name 的情况，不应用于虚 dad
		if user = 'ANONYMOUS' then
			-- this is for become user
			<<redo>>
			begin
				execute immediate 'call ' || r.dbu || '.dad_auth_entry()';
			exception
				when no_dad_auth_entry1 or no_dad_auth_entry2 then
					if v_done then
						raise;
					end if;
					sys.pw.add_dad_auth_entry(r.dbu);
					v_done := true;
					goto redo;
				when others then
					owa_util.mime_header('text/plain', true);
					htp.p('in servlet occurred dyna sp call error for dbu : ' || r.dbu);
					htp.p('error text = ' || sqlcode || '/' || sqlerrm);
			end;
		else
			-- when dad's user is the right db user
			k_gw.do;
		end if;
	else
		k_hook.map_url(r.file);
	end if;
	htp.p('x-pw-elapsed-time:' || (dbms_utility.get_time - v_elpt) * 10);
	htp.p('x-pw-cpu-time:' || (dbms_utility.get_cpu_time - v_cput) * 10);

end servlet;
/

