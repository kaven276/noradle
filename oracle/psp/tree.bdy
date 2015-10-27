create or replace package body tree is

	procedure rc
	(
		cuts     in out nocopy st,
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
		v_col_name varchar2(1000);
		v_collen   binary_integer;
		v_row_cnt  pls_integer := 0;
		v_lvl      number;
		v_fill     st := st();
	begin
		v_fill.extend(cuts.count - 3);
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
			v_col_name := lower(desctab(i).col_name);
			v_collen   := desctab(i).col_max_len;
		end loop;
	
		v_row_cnt := 0;
		while dbms_sql.fetch_rows(curid) > 0 loop
			v_row_cnt := v_row_cnt + 1;
		
			dbms_sql.column_value(curid, 1, v_number);
			v_lvl := v_number;
			for i in 2 .. colcnt loop
				case desctab(i).col_type
					when 1 then
						dbms_sql.column_value(curid, i, v_varchar2);
						v_fill(i - 1) := v_varchar2;
					when 2 then
						dbms_sql.column_value(curid, i, v_number);
						v_fill(i - 1) := to_char(v_number);
					when 12 then
						dbms_sql.column_value(curid, i, v_date);
						v_fill(i - 1) := to_char(v_date, coalesce(fmt_date, 'yyyy-mm-dd'));
					else
						dbms_sql.column_value(curid, i, v_other);
						v_fill(i - 1) := v_other;
				end case;
			end loop;
			r(v_lvl, cuts, v_fill);
		end loop;
	
		dbms_sql.close_cursor(curid);
		tmp.rows := v_row_cnt;
	end;

	procedure prc
	(
		tpl      varchar2,
		cur      in out nocopy sys_refcursor,
		fmt_date varchar2 := null,
		pretty   boolean := true,
		indent   boolean := true
	) is
		v_stv st;
	begin
		p(tpl, v_stv, indent);
		o(pretty);
		rc(v_stv, cur, fmt_date);
		c(v_stv);
	end;

	-- template parser for hierachical structure
	procedure p
	(
		tpl    varchar2,
		cuts   in out nocopy st,
		indent boolean := true
	) is
		pos1 pls_integer;
		pos2 pls_integer;
		pos3 pls_integer;
	begin
		pos1 := instrb(tpl, '|');
		pos2 := instrb(tpl, '|', pos1 + 1);
		pos3 := instrb(tpl, '|', pos2 + 1);
		t.split(cuts, substrb(tpl, 1, pos1 - 1), '@', false);
		if indent then
			cuts(1) := ltrim(cuts(1));
		end if;
		cuts.extend;
		cuts(cuts.count) := substrb(tpl, pos3 + 1); -- </li>
		cuts.extend;
		cuts(cuts.count) := substrb(tpl, pos1 + 1, pos2 - pos1 - 1); -- <ul>
		cuts.extend;
		cuts(cuts.count) := substrb(tpl, pos2 + 1, pos3 - pos2 - 1); -- </ul>
	end;

	procedure o(pretty boolean) is
	begin
		sts.olevel := null;
		sts.pretty := pretty;
	end;

	procedure c is
	begin
		c(tmp.stv);
	end;

	procedure c(cuts in out nocopy st) is
	begin
		if sts.olevel is null then
			return;
		end if;
		b.write(cuts(cuts.count - 2)); -- </li>
		for j in 1 .. sts.olevel - 1 loop
			b.write(cuts(cuts.count - 0)); -- </ul>
			b.write(cuts(cuts.count - 2)); -- </li>
		end loop;
		b.line;
	end;

	-- repeater for gen hierachical structure
	procedure r
	(
		level pls_integer,
		cuts  in out nocopy st,
		para  st
	) is
	begin
		if sts.olevel is not null then
			if level = sts.olevel + 1 then
				-- enter deeper level
				b.write(cuts(cuts.count - 1)); -- <li>
			else
				-- same level or level up
				b.write(cuts(cuts.count - 2)); -- </li>
				-- escape one or more level up
				for j in 1 .. sts.olevel - level loop
					-- return level
					b.write(cuts(cuts.count - 0)); -- </ul>
					b.write(cuts(cuts.count - 2)); -- </li>
				end loop;
			end if;
			if sts.pretty is null then
				b.write(chr(10));
			elsif sts.pretty then
				b.write(rpad(chr(10), level, ' '));
			end if;
		end if;
		sts.olevel := level;
	
		for i in 1 .. cuts.count - 4 loop
			b.write(cuts(i));
			b.write(para(i));
		end loop;
		b.write(cuts(cuts.count - 3));
	end;

	procedure n
	(
		level pls_integer,
		str   varchar2
	) is
	begin
		if sts.olevel is not null then
			if level = sts.olevel + 1 then
				-- enter deeper level
				b.write('<ul>');
			else
				-- same level or level up
				b.write('</li>');
				-- escape one or more level up
				for j in 1 .. sts.olevel - level loop
					-- return level
					b.write('</ul>');
					b.write('</li>');
				end loop;
			end if;
			if sts.pretty is null then
				b.write(chr(10));
			elsif sts.pretty then
				b.write(rpad(chr(10), level, ' '));
			end if;
		end if;
		sts.olevel := level;
	
		b.write(str);
	end;

	procedure n
	(
		level varchar2,
		str   varchar2
	) is
		v varchar2(4000) := ltrim(level);
	begin
		n(lengthb(level) - nvl(length(v), 0), v || str);
	end;

	procedure n(str varchar2) is
		v varchar2(4000) := ltrim(str);
	begin
		n(lengthb(str) - lengthb(v), v);
	end;

end tree;
/
