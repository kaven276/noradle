create or replace package pw is

	procedure add_dad_auth_entry(p_db_user varchar2);

	procedure recompile(p_sql varchar2);

end pw;
/
create or replace package body pw is

	procedure add_dad_auth_entry(p_db_user varchar2) is
	begin
		execute immediate 'create or replace procedure ' || p_db_user ||
											'.dad_auth_entry is begin k_gw.do; end;';
		execute immediate 'grant execute on ' || p_db_user || '.dad_auth_entry to public';
	end;

	procedure recompile(p_sql varchar2) is
	begin		
		-- dbms_alert.signal('pw.package_state_invalid',p_sql);
		-- commit;
		execute immediate p_sql;
	end;

end pw;
/
