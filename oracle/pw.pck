create or replace package sys.pw is

	procedure add_dad_auth_entry(p_db_user varchar2);

	procedure add_async_auth_entry(p_db_user varchar2);

	procedure recompile(p_sql varchar2);

end pw;
/
create or replace package body sys.pw is

	procedure add_dad_auth_entry(p_db_user varchar2) is
	begin
		execute immediate 'create or replace procedure ' || p_db_user || '.dad_auth_entry is begin k_gw.do; end;';
		execute immediate 'grant execute on ' || p_db_user || '.dad_auth_entry to ' || user;
	end;

	procedure add_async_auth_entry(p_db_user varchar2) is
	begin
		execute immediate 'create or replace procedure ' || p_db_user ||
											'.async_auth_entry(prog varchar2) is begin k_bg.do(prog); end;';
		execute immediate 'grant execute on ' || p_db_user || '.async_auth_entry to ' || user;
	end;

	procedure recompile(p_sql varchar2) is
	begin
		-- dbms_alert.signal('pw.package_state_invalid',p_sql);
		-- commit;
		execute immediate p_sql;
	end;

end pw;
/
