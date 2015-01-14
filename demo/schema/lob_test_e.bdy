create or replace package body lob_test_e is

	gv_blob blob;
	gv_size pls_integer := 16000;
	gv_pack pls_integer := 16; -- max 1024, min 8

	procedure do_lob is
		v_raw raw(1024) := utl_raw.copies(utl_raw.cast_to_raw('12345678'), gv_pack / 8);
	begin
		for i in 1 .. gv_size / gv_pack loop
			dbms_lob.write(gv_blob, gv_pack, (i - 1) * gv_pack + 1, v_raw);
		end loop;
	end;

	procedure do_varchar2 is
		v_char varchar2(1024) := utl_raw.cast_to_varchar2(utl_raw.copies(utl_raw.cast_to_raw('12345678'), gv_pack / 8));
		v_out  varchar2(32000);
	begin
		for i in 1 .. gv_size / gv_pack loop
			v_out := v_out || substr(v_char, 1, gv_pack);
		end loop;
	end;

	procedure do_raw is
		v_raw raw(512) := utl_raw.copies(utl_raw.cast_to_raw('12345678'), gv_pack / 8);
		v_out raw(32000) := utl_raw.copies(utl_raw.cast_to_raw('12345678'), 32000 / 8);
		v_tmp raw(512);
	begin
		for i in 1 .. gv_size / gv_pack loop
			-- v_out := utl_raw.concat(v_out, v_raw);
			v_tmp := utl_raw.overlay(v_raw, v_out, (i - 1) * gv_pack + 1, gv_pack);
		end loop;
	end;

	procedure test
	(
		rcomm varchar2 := 'lob',
		psize pls_integer := 16
	) is
	begin
		gv_pack := psize;
		select a.sid into tmp.n from v$mystat a where rownum = 1;
		dbms_output.put_line(tmp.n);
	
		dbms_hprof.start_profiling('PLSHPROF_DIR', 'lob.trc');
		lob_test.do_lob;
		dbms_hprof.stop_profiling;
		tmp.n := dbms_hprof.analyze('PLSHPROF_DIR', 'lob.trc', run_comment => rcomm);
		dbms_output.put_line(tmp.n);
	
		dbms_hprof.start_profiling('PLSHPROF_DIR', 'lob.trc');
		lob_test.do_varchar2;
		dbms_hprof.stop_profiling;
		tmp.n := dbms_hprof.analyze('PLSHPROF_DIR', 'lob.trc', run_comment => rcomm);
		dbms_output.put_line(tmp.n);
	end;

	procedure test_all_size is
	begin
		for i in 3 .. 10 loop
			gv_pack := power(2, i);
			test('size_' || gv_pack, gv_pack);
		end loop;
	end;

begin
	dbms_lob.createtemporary(gv_blob, cache => true, dur => dbms_lob.call);

end lob_test_e;
/
