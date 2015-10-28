create or replace package body k_gw is

	procedure error_not_exist is
	begin
		h.status_line(404);
		h.content_type;
		h.header_close;
		b.line('The program unit "' || r.prog || '" is not exist');
	end;

	procedure error_no_subprog is
	begin
		if not pv.msg_stream then
			h.status_line(404);
			h.content_type;
			h.header_close;
		end if;
		b.line('The package "' || r.pack || '" exists but the sub procedure "' || r.proc || '" in it' || ' is not exist');
	end;

	procedure error_execute
	(
		ecode      varchar2,
		emsg       varchar2,
		ebacktrace varchar2,
		estack     varchar2
	) is
	begin
		if not pv.msg_stream then
			h.status_line(500);
			h.content_type('text/html');
			h.header_close;
			x.p('<title>', emsg);
			x.p('<h3>', '[WARNING] execute with error');
			x.o('<pre>');
			b.line(estack);
			b.line(ebacktrace);
			x.c('</pre>');
			-- x.a('<a>', 'refresh', 'javascript:window.location.reload();');
		else
			b.line('[WARNING] execute with error');
			b.line(estack);
			b.line(ebacktrace);
		end if;
	end;

	procedure do is
		v_sql    varchar2(100);
		v_tried  boolean;
		v_before varchar2(60) := r.getc('x$before', '');
		v_after  varchar2(60) := r.getc('x$after', '');
	begin
		v_tried := false;
		<<retry_filter>>
		begin
			if v_before is not null then
				execute immediate 'call ' || v_before || '()';
			end if;
		exception
			when pv.ex_package_state_invalid then
				if v_tried then
					error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
					rollback;
					return;
				else
					v_sql := regexp_replace(dbms_utility.format_error_stack,
																	'^.*ORA-04061:( package (body )?"(\w+\.\w+)" ).*$',
																	'alter package \3 compile \2',
																	modifier => 'n');
					sys.pw.recompile(regexp_replace(dbms_utility.format_error_stack,
																					'^.*ORA-04061:( package (body )?"(\w+\.\w+)" ).*$',
																					'alter package \3 compile \2',
																					modifier => 'n'));
					v_tried := true;
					goto retry_filter;
				end if;
			when pv.ex_no_filter or pv.ex_invalid_proc then
				null;
			when pv.ex_resp_done then
				goto after;
			when others then
				error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
				rollback;
				return;
		end;
	
		v_tried := false;
		<<retry_prog>>
		begin
			execute immediate 'call ' || r.prog || '()';
		exception
			when pv.ex_package_state_invalid then
				if v_tried then
					error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
					rollback;
					return;
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
				error_not_exist;
			when pv.ex_no_subprog then
				error_no_subprog;
			when pv.ex_resp_done then
				goto after;
			when others then
				k_debug.trace(st('k_gw.do core', sqlcode, sqlerrm, dbms_utility.format_error_backtrace));
				error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
				rollback;
		end;
	
		<<after>>
		begin
			if v_after is not null then
				execute immediate 'call ' || v_after || '()';
			end if;
		exception
			when pv.ex_no_filter or pv.ex_invalid_proc then
				null;
			when pv.ex_resp_done then
				null;
			when others then
				error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
				rollback;
				return;
		end;
	
		if sts.stack is not null then
			output.line(sts.stack, '');
		end if;
	
		commit;
	end;

end k_gw;
/
