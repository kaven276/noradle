create or replace package body k_dad_adm is

	procedure create_dad(p_dad_name varchar2, p_db_user varchar2) is
		v_db_user varchar2(30) := upper(p_db_user);
		v_root    varchar2(400);
		v_dir     varchar2(30);
		v_path    varchar2(1000);
	begin
		-- xdb.dad_adm.build(p_dad_name, v_db_user);
		select t.directory_path
			into v_root
			from all_directories t
		 where t.owner = 'SYS'
			 and t.directory_name = 'PSPDADS';
	
		v_dir  := p_dad_name || '_ulf';
		v_path := v_root || '/' || p_dad_name || '/upload';
		execute immediate 'create or replace directory ' || v_dir || ' as ''' || v_path || '''';
		execute immediate 'grant read on directory ' || v_dir || ' to ' || 'anonymous';
		if v_db_user != 'PSP' then
			execute immediate 'grant read on directory ' || v_dir || ' to ' || v_db_user;
		end if;
	
		v_dir  := p_dad_name || '_cache';
		v_path := v_root || '/' || p_dad_name || '/cache';
		execute immediate 'create or replace directory ' || v_dir || ' as ''' || v_path || '''';
		execute immediate 'grant read on directory ' || v_dir || ' to ' || 'anonymous';
		if v_db_user != 'PSP' then
			execute immediate 'grant read on directory ' || v_dir || ' to ' || v_db_user;
		end if;
	
	end;

	procedure drop_dad(p_dad_name varchar2) is
		v_root varchar2(400);
		v_dir  varchar2(30);
	begin
		-- xdb.dad_adm.remove(p_dad_name);
		select t.directory_path
			into v_root
			from all_directories t
		 where t.owner = 'SYS'
			 and t.directory_name = 'PSPDADS';
	
		v_dir := p_dad_name || '_ulf';
		execute immediate 'drop directory ' || v_dir;
	
		v_dir := p_dad_name || '_cache';
		execute immediate 'drop directory ' || v_dir;
	end;

	procedure create_repo(p_dad_name varchar2, p_db_user varchar2 := null, p_link_dad_name varchar2 := null) is
		v_bool boolean;
	begin
		v_bool := dbms_xdb.createfolder('/psp.web/pspapps/' || p_dad_name);
	end;

	function map_dbuser(p_dadname varchar2) return varchar2 result_cache relies_on(dad_t) is
		v_cnt     pls_integer;
		v_db_user dad_t.db_user%type;
	begin
		select a.db_user into v_db_user from dad_t a where a.dad_name = p_dadname;
		return v_db_user;
	exception
		when no_data_found then
			select count(*) into v_cnt from dba_users a where a.username = upper(p_dadname);
			if v_cnt = 1 and false then
				return p_dadname;
			else
				select max(a.db_user) into v_db_user from dad_t a where a.disp_order = 0;
				return nvl(v_db_user, p_dadname);
			end if;
	end;

end k_dad_adm;
/

