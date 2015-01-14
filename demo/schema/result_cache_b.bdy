create or replace package body result_cache_b is

	gv_user user_t%rowtype;

	function get_user(p_name varchar2) return user_t%rowtype result_cache is
	begin
		dbms_lock.sleep(1);
		select a.* into gv_user from user_t a where a.name = p_name;
		-- set this cache-key to GAC,
		-- so trigger can invalidate
		--select dbms_flashback.get_system_change_number into tmp.scn from dual;
		--dbms_output.put_line(tmp.scn);
		tmp.k := 1;
		return gv_user;
	end;

	procedure trg_chg(p_name varchar2) is
	begin
		null;
	end;

	procedure set_pv_user(p_name varchar2) is
	begin
		tmp.k   := 0;
		gv_user := get_user(p_name);
		/*
		pipe type,key,value to bg job to update
		if tmp.k = 1 then
			select max(a.id)
				into gv_user.cache_id
				from v$result_cache_objects a
			 where a.name like '"DEMO1"."RESULT_CACHE_B"%'
				 and a.status = 'Published';
			update user_t a set a.cache_id = gv_user.cache_id where a.name = p_name;
		end if;
		*/
	end;

	procedure print_user is
		v       user_t%rowtype;
		v_stime number := dbms_utility.get_time;
		p_user  varchar2(30) := r.getc('name', 'liyong');
	begin
		for i in 1 .. 1000 loop
			v := get_user(p_user);
		end loop;
		x.p('<h2>', dbms_utility.get_time - v_stime);
		x.p('<p>', v.name);
		x.p('<p>', v.pass);
		x.p('<p>', to_char(v.ctime));
	end;

	procedure output_user is
		v       user_t%rowtype;
		v_stime number := dbms_utility.get_cpu_time;
		p_user  varchar2(30) := r.getc('name', 'liyong');
	begin
		select a.* into gv_user from user_t a where a.name = p_user;
		for i in 1 .. 5000 loop
			v := get_user(p_user);
		end loop;
		dbms_output.put_line(dbms_utility.get_cpu_time - v_stime);
		x.p('<p>', v.name);
		x.p('<p>', v.pass);
		x.p('<p>', to_char(v.ctime));
	end;

end result_cache_b;
/
