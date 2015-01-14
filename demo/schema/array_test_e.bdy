create or replace package body array_test_e is
	pragma serially_reusable;

	val pls_integer := 0;

	type table_arr is table of nvarchar2(32767);
	type index_arr is table of nvarchar2(32767) index by pls_integer;
	type index_map is table of nvarchar2(32767) index by varchar2(100);

	procedure before is
	begin
		dbms_hprof.start_profiling('PLSHPROF_DIR', 'test.trc');
	end;

	procedure after(comment varchar2) is
	begin
		dbms_hprof.stop_profiling;
		tmp.n := dbms_hprof.analyze('PLSHPROF_DIR', 'test.trc', run_comment => comment);
		dbms_output.put_line(tmp.n);
	end;

	procedure arr_compare(amount pls_integer := 100) is
		v1 index_arr;
		v2 table_arr;
		procedure v1test is
		begin
			v1.delete;
			for i in 1 .. amount loop
				v1(i) := 'abcd';
			end loop;
		end;
		procedure v2test is
		begin
			v2.delete;
			for i in 1 .. amount loop
				v2.extend;
				v2(i) := 'abcd';
			end loop;
		end;
	begin
		before;
		v1test;
		v2test;
		after('arr_test');
	end;

	procedure str_len_compare is
		v varchar2(32767);
		n pls_integer := floor(32767 / 14);
		u varchar2(100);
		procedure t1 is
		begin
			for i in 1 .. n * 2 loop
				v := v || 'abcdefg';
			end loop;
		end;
		procedure t2 is
		begin
			for i in 1 .. n loop
				u := 'abcdefgabcdefg';
				v := v || u;
			end loop;
		end;
		procedure t3 is
		begin
			for i in 1 .. n loop
				u := 'abcdefg';
				u := u || 'abcdefg';
				v := v || u;
			end loop;
		end;
		procedure t4 is
		begin
			for i in 1 .. floor(n / 2) loop
				u := 'abcdefg';
				u := u || 'abcdefg';
				u := u || 'abcdefg';
				u := u || 'abcdefg';
				v := v || u;
			end loop;
		end;
	begin
		before;
		t1;
		v := '';
		t2;
		v := '';
		t3;
		v := '';
		t4;
		after('str_len');
	end;

	procedure simple_arr_compare is
		v_cnt pls_integer := 3276;
		procedure simple is
			v varchar2(32767);
		begin
			for i in 1 .. v_cnt loop
				v := v || '1234567890';
			end loop;
		end;
		procedure indexby is
			v index_arr;
		begin
			v(1) := '';
			for i in 1 .. v_cnt loop
				v(1) := v(1) || '1234567890';
			end loop;
		end;
		procedure nested is
			v table_arr := table_arr('');
		begin
			for i in 1 .. v_cnt loop
				v(1) := v(1) || '1234567890';
			end loop;
		end;
	begin
		before;
		simple;
		indexby;
		nested;
		after('simple_arr_compare');
	end;

	procedure serial_reuse_outer is
	begin
		-- dbms_output.put_line(val);
		execute immediate 'call tests.serial_reuse_inner()';
		execute immediate 'call tests.serial_reuse_inner()';
		dbms_output.put_line(val);
	end;

	procedure serial_reuse_inner is
	begin
		dbms_output.put_line('inner head :' || val);
		val := val + 1;
		dbms_output.put_line('inner tail :' || val);
	end;

	procedure indexby_exist is
		v index_map;
	begin
		dbms_output.put_line(t.tf(v.exists('a'), 'exist', 'not exist'));
		dbms_output.put_line('v(a)=' || v('a'));
	end;

end array_test_e;
/
