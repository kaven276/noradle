create or replace package body k_sql is

	procedure get is
		v_tvname varchar2(30) := r.proc;
		v_qstr   varchar2(4000) := r.qstr;
		v_sql    varchar2(4000) := 'select * from ' || v_tvname;
		cur      sys_refcursor;
	begin
		if v_qstr is not null then
			v_sql := v_sql || ' where ' || replace(v_qstr, '&', ' and ');
		end if;
		k_debug.trace(v_sql);
		open cur for v_sql;
		rs.print(cur);
	end;

end k_sql;
/
