create or replace package body multi is

	type pairs_t is ref cursor;

	procedure split
	(
		p    varchar2,
		cuts in out nocopy st,
		sep  varchar2 := ','
	) is
		v_pos pls_integer;
		v_old pls_integer := 0;
		v_cnt pls_integer := 0;
	begin
		cuts := st();
		loop
			v_pos := instr(p, sep, v_old + 1, 1);
			exit when v_pos = 0 or v_pos is null;
			cuts.extend;
			v_cnt := v_cnt + 1;
			cuts(v_cnt) := trim(substr(p, v_old + 1, v_pos - v_old - 1));
			v_old := v_pos;
		end loop;
		cuts.extend;
		cuts(v_cnt + 1) := trim(substr(p, v_old + 1));
	end;

	function join
	(
		cuts in out nocopy st,
		sep  varchar2 := ','
	) return varchar2 is
		s varchar2(4000);
	begin
		s := cuts(1);
		for i in 2 .. cuts.count loop
			s := s || sep || cuts(i);
		end loop;
		return s;
	end;

	procedure split2
	(
		pairs varchar2,
		sep   varchar2 := ';:'
	) is
		v_single boolean := length(sep) = 1;
		v_sep1   char(1) := substrb(sep, 1, 1);
		v_count  pls_integer;
		v_pos    pls_integer;
		v_old    pls_integer := 0;
		v_pos2   pls_integer;
		v_sep2   char(1);
	begin
		v_single := length(sep) = 1;
		if not v_single then
			v_sep2 := substr(sep, 2, 1);
		end if;
		sts.gv_texts  := st();
		sts.gv_values := st();
		v_count       := length(regexp_replace(pairs, '[^' || v_sep1 || ']', ''));
		sts.gv_texts.extend(v_count);
		sts.gv_values.extend(v_count);
		for i in 1 .. v_count loop
			v_pos := instr(pairs, v_sep1, v_old + 1, 1);
			sts.gv_texts(i) := substr(pairs, v_old + 1, v_pos - v_old - 1);
			if v_single then
				sts.gv_values(i) := sts.gv_texts(i);
			else
				v_pos2 := instr(sts.gv_texts(i), v_sep2);
				if v_pos2 > 0 then
					sts.gv_values(i) := substr(sts.gv_texts(i), v_pos2 + 1);
					sts.gv_texts(i) := substr(sts.gv_texts(i), 1, v_pos2 - 1);
				else
					sts.gv_values(i) := sts.gv_texts(i);
				end if;
			end if;
			v_old := v_pos;
		end loop;
	end;

	function f
	(
		cur pairs_t,
		n   in out nocopy st,
		v   in out nocopy st
	) return number is
		i       pls_integer := 0;
		v_text  varchar2(1000);
		v_value varchar2(1000);
	begin
		n := st();
		v := st();
		loop
			fetch cur
				into v_text, v_value;
			exit when cur%notfound;
			n.extend;
			v.extend;
			i := i + 1;
			n(i) := v_text;
			v(i) := v_value;
		end loop;
		close cur;
		return i;
	end;

	procedure f
	(
		cur pairs_t,
		n   in out nocopy st,
		v   in out nocopy st
	) is
		v_dummy number;
	begin
		v_dummy := f(cur, n, v);
	end;

	function w
	(
		head  varchar2,
		texts st,
		tail  varchar2
	) return varchar2 is
		v_rtn varchar2(32000);
	begin
		for i in 1 .. texts.count loop
			v_rtn := v_rtn || head || texts(i) || tail;
		end loop;
		return v_rtn;
	end;

	procedure w
	(
		head   varchar2,
		texts  st,
		tail   varchar2,
		indent boolean := true
	) is
		v_head varchar2(4000);
	begin
		if indent then
			v_head := ltrim(head);
		else
			v_head := head;
		end if;
		for i in 1 .. texts.count loop
			k_xhtp.prn(v_head || texts(i) || tail);
		end loop;
		k_xhtp.line;
	end;

	function w
	(
		tpl   varchar2,
		texts st
	) return varchar2 is
		v_rtn varchar2(32000);
	begin
		for i in 1 .. texts.count loop
			v_rtn := v_rtn || replace(tpl, '@', texts(i));
		end loop;
		return v_rtn;
	end;

	procedure w
	(
		tpl    varchar2,
		texts  st,
		indent boolean := true
	) is
		v_tpl varchar2(4000);
	begin
		if indent then
			v_tpl := ltrim(tpl);
		else
			v_tpl := tpl;
		end if;
		for i in 1 .. texts.count loop
			k_xhtp.prn(replace(v_tpl, '@', texts(i)));
		end loop;
		k_xhtp.line;
	end;

	function w
	(
		tpl   varchar2,
		texts varchar2
	) return varchar2 is
		v_pos  pls_integer := instrb(tpl, '@');
		v_head varchar2(4000) := substrb(tpl, 1, v_pos - 1);
		v_tail varchar2(4000) := substrb(tpl, v_pos + 1);
	begin
		return v_head || replace(texts, ',', v_tail || v_head) || v_tail;
	end;

	procedure w
	(
		tpl    varchar2,
		texts  varchar2,
		indent boolean := true
	) is
		v_pos  pls_integer := instrb(tpl, '@');
		v_head varchar2(4000) := substrb(tpl, 1, v_pos - 1);
		v_tail varchar2(4000) := substrb(tpl, v_pos + 1);
	begin
		if indent then
			v_head := ltrim(v_head);
		end if;
		k_xhtp.line(v_head || replace(texts, ',', v_tail || v_head) || v_tail);
	end;

	procedure w
	(
		tpl    varchar2,
		cur    sys_refcursor,
		sv     varchar2,
		indent boolean := true
	) is
		v  varchar2(4000);
		n  varchar2(4000);
		p1 pls_integer := instrb(tpl, '?');
		b  varchar2(99) := substrb(regexp_substr(tpl, '\?\w+ ', p1, 1), 2);
		p2 pls_integer := p1 + lengthb(b);
		p3 pls_integer := instrb(tpl, '@', p2 + 1);
		p4 pls_integer := instrb(tpl, '@', p3 + 1);
		t1 varchar2(4000) := substrb(tpl, 1, p1 - 1);
		t2 varchar2(4000) := substrb(tpl, p2 + 1, p3 - p2 - 1);
		t3 varchar2(4000) := substrb(tpl, p3 + 1, p4 - p3 - 1);
		t4 varchar2(4000) := substrb(tpl, p4 + 1);
		sw varchar2(4000) := ',' || sv || ',';
	begin
		if indent then
			t1 := ltrim(t1);
		end if;
		loop
			fetch cur
				into v, n;
			exit when cur%notfound;
			if instr(sw, ',' || v || ',') = 0 then
				k_xhtp.line(t1 || t2 || v || t3 || n || t4);
			else
				k_xhtp.line(t1 || b || t2 || v || t3 || n || t4);
			end if;
		end loop;
	end;

	function w
	(
		tpl varchar2,
		cur sys_refcursor,
		sv  varchar2
	) return varchar2 is
		v   varchar2(4000);
		n   varchar2(4000);
		p1  pls_integer := instrb(tpl, '?');
		b   varchar2(99) := substrb(regexp_substr(tpl, '\?\w+ ', p1, 1), 2);
		p2  pls_integer := p1 + lengthb(b);
		p3  pls_integer := instrb(tpl, '@', p2 + 1);
		p4  pls_integer := instrb(tpl, '@', p3 + 1);
		t1  varchar2(4000) := substrb(tpl, 1, p1 - 1);
		t2  varchar2(4000) := substrb(tpl, p2 + 1, p3 - p2 - 1);
		t3  varchar2(4000) := substrb(tpl, p3 + 1, p4 - p3 - 1);
		t4  varchar2(4000) := substrb(tpl, p4 + 1);
		sw  varchar2(4000) := ',' || sv || ',';
		rtn varchar2(32000);
	begin
		loop
			fetch cur
				into v, n;
			exit when cur%notfound;
			if instr(sw, ',' || v || ',') = 0 then
				rtn := rtn || (t1 || t2 || v || t3 || n || t4);
			else
				rtn := rtn || (t1 || b || t2 || v || t3 || n || t4);
			end if;
		end loop;
		return rtn;
	end;

	-- template parser for flat structure
	procedure p
	(
		tpl    varchar2,
		cuts   in out nocopy st,
		indent boolean := true
	) is
	begin
		split(tpl, cuts, '@');
		if indent then
			cuts(1) := ltrim(cuts(1));
		end if;
	end;

	-- repeater for flat structure
	procedure r
	(
		cuts in out nocopy st,
		para st
	) is
	begin
		for i in 1 .. para.count loop
			k_xhtp.prn(cuts(i));
			k_xhtp.prn(para(i));
		end loop;
		k_xhtp.line(cuts(para.count + 1));
	end;

	-- template parser for hierachical structure
	procedure p
	(
		tpl      varchar2,
		list_tag varchar2,
		cuts     in out nocopy st,
		indent   boolean := true
	) is
		pos  pls_integer;
		head varchar2(4000);
		tail varchar2(30);
	begin
		pos  := instrb(tpl, '|');
		head := substrb(tpl, 1, pos - 1);
		tail := substrb(tpl, pos + 1);
		split(head, cuts, '@');
		if indent then
			cuts(1) := ltrim(cuts(1));
		end if;
		cuts.extend;
		cuts(cuts.count) := tail;
		cuts.extend;
		cuts(cuts.count) := list_tag;
		cuts.extend;
		cuts(cuts.count) := '</' || substrb(list_tag, 2);
	end;

	procedure ro(pretty boolean := null) is
	begin
		sts.olevel := null;
		sts.pretty := pretty;
	end;

	-- repeater for gen hierachical structure
	procedure r
	(
		cuts  in out nocopy st,
		level pls_integer,
		para  st
	) is
	begin
		if sts.olevel is not null then
			if level = sts.olevel + 1 then
				-- enter deeper level
				k_xhtp.prn(cuts(cuts.count - 1));
				sts.olevel := level;
			else
				-- same level or level up
				k_xhtp.prn(cuts(cuts.count - 2));
				-- escape one or more level up
				for j in 1 .. sts.olevel - level loop
					-- return level
					k_xhtp.prn(cuts(cuts.count - 0));
					k_xhtp.prn(cuts(cuts.count - 2));
				end loop;
				sts.olevel := level;
			end if;
			if sts.pretty is null then
				k_xhtp.prn(chr(10));
			elsif sts.pretty then
				k_xhtp.prn(rpad(chr(10), level, ' '));
			end if;
		else
			sts.olevel := 1;
		end if;
	
		for i in 1 .. para.count loop
			k_xhtp.prn(cuts(i));
			k_xhtp.prn(para(i));
		end loop;
		k_xhtp.prn(cuts(cuts.count - 3));
	end;

	procedure rc(cuts in out nocopy st) is
	begin
		if sts.olevel is null then
			return;
		end if;
		k_xhtp.prn(cuts(cuts.count - 2));
		for j in 1 .. sts.olevel - 1 loop
			k_xhtp.prn(cuts(cuts.count - 0));
			k_xhtp.prn(cuts(cuts.count - 2));
		end loop;
		k_xhtp.line;
	end;

	procedure c
	(
		tpl      varchar2,
		cur      in out nocopy sys_refcursor,
		fmt_date varchar2 := null
	) is
		curid      number;
		desctab    dbms_sql.desc_tab;
		colcnt     number;
		v_varchar2 varchar2(2000);
		v_number   number;
		v_date     date;
		v_other    varchar2(2000);
		v_count    pls_integer;
		v_cuts     st;
	begin
		split(tpl, v_cuts, '@');
		curid := dbms_sql.to_cursor_number(cur);
		dbms_sql.describe_columns(curid, colcnt, desctab);
	
		for i in 1 .. colcnt loop
			case desctab(i).col_type
				when 1 then
					dbms_sql.define_column(curid, i, v_varchar2, 2000);
				when 2 then
					dbms_sql.define_column(curid, i, v_number);
				when 12 then
					dbms_sql.define_column(curid, i, v_date);
				else
					dbms_sql.define_column(curid, i, v_other, 2000);
			end case;
		end loop;
	
		-- Fetch Rows
		v_count := 0;
		while dbms_sql.fetch_rows(curid) > 0 loop
			v_count := v_count + 1;
		
			for i in 1 .. colcnt loop
				k_xhtp.prn(v_cuts(i));
				case desctab(i).col_type
					when 1 then
						dbms_sql.column_value(curid, i, v_varchar2);
						k_xhtp.prn(v_varchar2);
					when 2 then
						dbms_sql.column_value(curid, i, v_number);
						k_xhtp.prn(to_char(v_number));
					when 12 then
						dbms_sql.column_value(curid, i, v_date);
						k_xhtp.prn(to_char(v_date, coalesce(fmt_date, 'yyyy-mm-dd')));
					else
						dbms_sql.column_value(curid, i, v_other);
						k_xhtp.prn(v_other);
				end case;
			end loop;
			k_xhtp.line(v_cuts(colcnt + 1));
		end loop;
		dbms_sql.close_cursor(curid);
	exception
		when no_data_found then
			dbms_sql.close_cursor(curid);
	end;

end multi;
/
