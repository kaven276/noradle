create or replace package body page_gen_speed_test is

	type lst is table of varchar2(32767);

	gv_str  varchar2(32767);
	gv_arr  owa.vc_arr;
	gv_st   lst;
	gv_clob clob;

	gv_total_size   number(10); -- 一共要生成多大的文件
	gc_line_size    pls_integer;
	gc_lobpage_size pls_integer;
	gc_line         varchar2(32767);
	gc_lobpage      varchar2(32767);
	gc_empty_arr    owa.vc_arr;

	procedure str is
		i pls_integer := 0;
		buf exception; -- table or view does not exist
		pragma exception_init(buf, -6502);
	begin
		gv_str := '';
		i      := dbms_utility.get_cpu_time;
		for j in 1 .. gv_total_size / gc_line_size loop
			begin
				gv_str := gv_str || gc_line;
			exception
				when buf then
					gv_str := '';
			end;
		end loop;
		htp.br;
		htp.print('varchar2(32767) writes :' || (dbms_utility.get_cpu_time - i));
		htp.br;
		htp.print(lengthb(gv_str));
	end;

	procedure arr is
		i pls_integer;
	begin
		gv_arr := gc_empty_arr;
		i      := dbms_utility.get_cpu_time;
		for j in -1 .. gv_total_size / gc_line_size loop
			gv_arr(j) := gc_line;
		end loop;
		htp.br;
		htp.print('owa.vc_arr writes :' || (dbms_utility.get_cpu_time - i));

		i := dbms_utility.get_cpu_time;
		for j in 1 .. gv_total_size / gc_line_size loop
			gv_str := gv_arr(j);
		end loop;
		htp.br;
		htp.print('owa.vc_arr reads :' || (dbms_utility.get_cpu_time - i));
	end;

	procedure st is
		i pls_integer;
	begin
		gv_st := lst();
		i     := dbms_utility.get_cpu_time;
		for j in 1 .. gv_total_size / gc_line_size loop
			gv_st.extend;
			gv_st(j) := gc_line;
		end loop;
		htp.br;
		htp.print('lst writes :' || (dbms_utility.get_cpu_time - i));

		i := dbms_utility.get_cpu_time;
		for j in 1 .. gv_total_size / gc_line_size loop
			gv_str := gv_st(j);
		end loop;
		htp.br;
		htp.print('lst reads :' || (dbms_utility.get_cpu_time - i));
	end;

	procedure lob_append is
		i  pls_integer;
		wb pls_integer;
		wa pls_integer;
	begin
		dbms_lob.createtemporary(gv_clob, true, dbms_lob.call);
		i := dbms_utility.get_cpu_time;
		select a.value into wb from v$sysstat a where a.name like 'lob writes unaligned';
		for j in 1 .. gv_total_size / gc_lobpage_size loop
			dbms_lob.writeappend(gv_clob, gc_lobpage_size, gc_lobpage);
		end loop;
		htp.br;
		htp.print('clob append writes :' || (dbms_utility.get_cpu_time - i));

		i      := dbms_utility.get_cpu_time;
		gv_str := instr(gv_clob, 'b');
		htp.br;
		htp.print('clob read :' || (dbms_utility.get_cpu_time - i));

		select a.value into wa from v$sysstat a where a.name like 'lob writes unaligned';
		htp.br;
		htp.print(lengthb(gc_lobpage));
		htp.print(wa - wb);

	end;

	procedure lob_write is
		i pls_integer;
	begin
		dbms_lob.createtemporary(gv_clob, true, dbms_lob.call);
		dbms_lob.write(gv_clob, 1, gv_total_size, ' ');
		i := dbms_utility.get_cpu_time;
		for j in 1 .. gv_total_size / gc_lobpage_size loop
			dbms_lob.write(gv_clob, gc_lobpage_size, (j - 1) * gc_lobpage_size + 1, gc_lobpage);
		end loop;
		htp.br;
		htp.print('clob write inplace :' || (dbms_utility.get_cpu_time - i));
	end;

	procedure allt
	(
		p_total_size   number,
		p_line_size    pls_integer,
		p_lobpage_size pls_integer
	) is
	begin
		-- dbms_session.modify_package_state(dbms_session.reinitialize);
		gv_total_size   := p_total_size;
		gc_line_size    := p_line_size;
		gc_lobpage_size := p_lobpage_size;

		gc_line    := rpad('a', gc_line_size, 'a');
		gc_lobpage := rpad('a', gc_lobpage_size, 'a');

		htp.init;
		htp.print('p_total_size :' || to_char(p_total_size, '999,999,999'));
		htp.br;
		htp.print('p_totap_line_sizel_size :' || to_char(p_line_size, '999,999,999'));
		htp.br;
		htp.print('p_lobpage_size :' || to_char(p_lobpage_size, '999,999,999'));
		str;
		arr;
		st;
		lob_append;
		--lob_write;
	end;

	-- 证明string操作，局部变量的包变量的性能几乎是一样的
	procedure static2local(cnt number) is
		i      pls_integer := 0;
		v_str  varchar2(32000);
		v_str2 varchar2(32000);
	begin
		gv_str := rpad('a', 32000, 'a');
		gv_arr(1) := gv_str;
		gv_arr(10) := gv_str;
		gv_arr(100) := gv_str;
		gv_arr(1000) := gv_str;

		i := dbms_utility.get_cpu_time;
		for i in 1 .. cnt loop
			v_str := gv_arr(1);
		end loop;
		htp.br;
		htp.print('copy v_str := gv_arr(1) ' || cnt || ' counts, spend 1/100s ' ||
							(dbms_utility.get_cpu_time - i));

		i := dbms_utility.get_cpu_time;
		for i in 1 .. cnt loop
			v_str := gv_arr(10);
		end loop;
		htp.br;
		htp.print('copy v_str := gv_arr(10) ' || cnt || ' counts, spend 1/100s ' ||
							(dbms_utility.get_cpu_time - i));

		i := dbms_utility.get_cpu_time;
		for i in 1 .. cnt loop
			v_str := gv_arr(100);
		end loop;
		htp.br;
		htp.print('copy v_str := gv_arr(100) ' || cnt || ' counts, spend 1/100s ' ||
							(dbms_utility.get_cpu_time - i));

		i := dbms_utility.get_cpu_time;
		for i in 1 .. cnt loop
			v_str := gv_arr(1000);
		end loop;
		htp.br;
		htp.print('copy v_str := gv_arr(1000) ' || cnt || ' counts, spend 1/100s ' ||
							(dbms_utility.get_cpu_time - i));

		i := dbms_utility.get_cpu_time;
		for i in 1 .. cnt loop
			v_str := gv_str;
		end loop;
		htp.br;
		htp.print('copy v_str := gv_str ' || cnt || ' counts, spend 1/100s ' ||
							(dbms_utility.get_cpu_time - i));

		i := dbms_utility.get_cpu_time;
		for i in 1 .. cnt loop
			v_str2 := v_str;
		end loop;
		htp.br;
		htp.print('copy v_str2 := v_str ' || cnt || ' counts, spend 1/100s ' ||
							(dbms_utility.get_cpu_time - i));

	end;

	procedure str2 is
		i pls_integer := 0;
		buf exception; -- table or view does not exist
		pragma exception_init(buf, -6502);
		lcnt pls_integer := 100;
	begin
		for k in 1 .. lcnt loop
			i      := dbms_utility.get_cpu_time;
			gv_str := '';
			for j in 1 .. 32000 loop
				gv_str := gv_str || 'a';
			end loop;
		end loop;
		htp.br;
		htp.print('varchar2(32767) writes :' || (dbms_utility.get_cpu_time - i));
		htp.br;
		htp.print(lengthb(gv_str));

		i := dbms_utility.get_cpu_time;
		for k in 1 .. lcnt loop
			gv_str := '';
			for j in 1 .. floor(32000 / 20) loop
				gv_str := gv_str || 'abcdefghijabcdefghij';
			end loop;
		end loop;
		htp.br;
		htp.print('varchar2(32767) writes :' || (dbms_utility.get_cpu_time - i));
		htp.br;
		htp.print(lengthb(gv_str));

		i := dbms_utility.get_cpu_time;
		for k in 1 .. lcnt loop
			gv_str := '';
			for j in 1 .. 3200 loop
				gv_str := gv_str || 'abcdefghij';
			end loop;
		end loop;
		htp.br;
		htp.print('varchar2(32767) writes :' || (dbms_utility.get_cpu_time - i));
		htp.br;
		htp.print(lengthb(gv_str));
	end;

	procedure lob_aligned_test is
		wb pls_integer;
		wa pls_integer;
	begin
		gc_lobpage := rpad('a', 32767);
		htp.p(gc_lobpage);
		htp.p(lengthb(gc_lobpage));
		htp.p(length(gc_lobpage));
		htp.br;

		for j in 16264 .. 16264 loop
			dbms_lob.createtemporary(gv_clob, true, dbms_lob.call);
			select a.value into wb from v$sysstat a where a.name like 'lob writes unaligned';
			dbms_lob.writeappend(gv_clob, j, gc_lobpage);
			select a.value into wa from v$sysstat a where a.name like 'lob writes unaligned';
			if wb = wa then
				htp.p(j);
				exit;
			end if;
		end loop;
	end;

end page_gen_speed_test;
/

