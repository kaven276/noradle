create or replace package body k_gw is

	procedure error_not_exist is
	begin
		h.status_line(404);
		h.content_type;
		h.header_close;
		p.line('The program unit "' || r.prog || '" is not exist');
	end;

	procedure error_execute
	(
		ecode      varchar2,
		emsg       varchar2,
		ebacktrace varchar2,
		estack     varchar2
	) is
	begin
		h.status_line(500);
		h.content_type('text/html');
		h.header_close;
		p.init;
		p.h('', emsg);
		p.hn(3, '[WARNING] execute with error');
		p.pre_open;
		p.d(estack);
		p.d(ebacktrace);
		p.pre_close;
		-- p.a('refresh', 'javascript:window.location.reload();');
	end;

	procedure do is
		v_sql varchar2(100);
		v_len pls_integer;
	begin
		v_sql := 'call ' || r.prog || '()';
		begin
			execute immediate v_sql;
			commit;
		exception
			when pv.ex_no_prog then
				error_not_exist;
			when pv.ex_resp_done then
				commit;
			when others then
				error_execute(sqlcode, sqlerrm, dbms_utility.format_error_backtrace, dbms_utility.format_error_stack);
				rollback;
		end;
	end;

end k_gw;
/
