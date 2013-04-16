create or replace package body k_bg is

	procedure do(p_prog varchar2) is
		v_prog  varchar2(99);
		v_sql   varchar2(100);
		v_tried boolean := false;
	begin
		if p_prog is null then
			dbms_pipe.unpack_message(v_prog);
		else
			v_prog := p_prog;
		end if;
	
		<<retry_prog>>
		begin
			execute immediate 'call ' || v_prog || '()';
			commit;
		exception
			when pv.ex_package_state_invalid then
				if v_tried then
					k_debug.trace('async:ex_package_state_invalid', v_prog);
					rollback;
				else
					v_sql := regexp_replace(dbms_utility.format_error_stack,
																	'^.*ORA-04061:( package (body )?"(\w+\.\w+)" ).*$',
																	'alter package \3 compile \2',
																	modifier => 'n');
					sys.pw.recompile(v_sql);
					v_tried := true;
					goto retry_prog;
				end if;
			when pv.ex_no_prog or pv.ex_invalid_proc then
				k_debug.trace(st('async:no prog or invalid prog', v_prog));
			when pv.ex_no_subprog then
				k_debug.trace(st('async:no subprog', v_prog));
			when pv.ex_resp_done then
				null;
			when others then
				k_debug.trace(st(sqlcode, sqlerrm, dbms_utility.format_error_stack));
				rollback;
				raise;
		end;
	end;

end k_bg;
/
