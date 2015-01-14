create or replace package body speed_test_e is

	procedure start_time is
	begin
		tmp.n := dbms_utility.get_cpu_time;
	end;

	procedure report
	(
		p_cnt pls_integer,
		info  varchar2
	) is
	begin
		dbms_output.put_line(info);
		dbms_output.put_line((dbms_utility.get_cpu_time - tmp.n) / p_cnt * 10);
		dbms_output.put_line('');
	end;

	procedure gac_get(p_cnt pls_integer) is
		v varchar2(30);
	begin
		dbms_session.clear_identifier;
		dbms_session.set_context('GAC_SPEED_TEST', 'KEY1', 'VAL1');
		start_time;
		for i in 1 .. p_cnt loop
			v := sys_context('GAC_SPEED_TEST', 'KEY1');
		end loop;
		report(p_cnt, 'GAC sys_context get');
	end;

	procedure pv_get(p_cnt pls_integer) is
		v varchar2(30);
	begin
		tmp.s := 'VAL1';
		start_time;
		for i in 1 .. p_cnt loop
			v := tmp.s || i;
		end loop;
		report(p_cnt, 'PV tmp.s get');
	end;

	procedure dual_get(p_cnt pls_integer) is
		v varchar2(30);
	begin
		start_time;
		for i in 1 .. p_cnt loop
			select dummy into v from dual;
		end loop;
		report(p_cnt, 'SQL select dual');
	end;

	procedure dual_get_rc(p_cnt pls_integer) is
		v varchar2(30);
	begin
		start_time;
		for i in 1 .. p_cnt loop
			select /* result-cache */
			 dummy
				into v
				from dual;
		end loop;
		report(p_cnt, 'SQL select dual by result cache');
	end;

	procedure table_get(p_cnt pls_integer) is
		v user_t%rowtype;
	begin
		start_time;
		for i in 1 .. p_cnt loop
			select a.* into v from user_t a where rownum = 1;
		end loop;
		report(p_cnt, 'SQL select user_t');
	end;

	procedure table_get_rc(p_cnt pls_integer) is
		v user_t%rowtype;
	begin
		start_time;
		for i in 1 .. p_cnt loop
			select /* result-cache */
			 a.*
				into v
				from user_t a
			 where rownum = 1;
		end loop;
		report(p_cnt, 'SQL select dual by result cache');
	end;

	procedure all_test(p_cnt pls_integer) is
	begin
		speed_test_e.gac_get(p_cnt);
		speed_test_e.pv_get(p_cnt);
		speed_test_e.dual_get(p_cnt);
		speed_test_e.dual_get_rc(p_cnt);
		speed_test_e.table_get(p_cnt);
		speed_test_e.table_get_rc(p_cnt);
	end;

end speed_test_e;
/
