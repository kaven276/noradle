create or replace package body tree is

	procedure cur
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
			m.r(cuts, v_lvl, v_fill);
		end loop;
	
		dbms_sql.close_cursor(curid);
		tmp.rows := v_row_cnt;
	end;

	procedure o
	(
		pretty boolean,
		tags   varchar2 := 'ul,li'
	) is
	begin
		sts.olevel := null;
		sts.pretty := pretty;
	end;

	procedure c is
	begin
		if sts.olevel is null then
			return;
		end if;
		k_xhtp.prn('</li>');
		for j in 1 .. sts.olevel - 1 loop
			k_xhtp.prn('</ul>');
			k_xhtp.prn('</li>');
		end loop;
		k_xhtp.line;
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
				k_xhtp.prn('<ul>');
				sts.olevel := level;
			else
				-- same level or level up
				k_xhtp.prn('</li>');
				-- escape one or more level up
				for j in 1 .. sts.olevel - level loop
					-- return level
					k_xhtp.prn('</ul>');
					k_xhtp.prn('</li>');
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
	
		k_xhtp.prn(str);
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
	begin
		n(lengthb(str) - length(ltrim(str)), str);
	end;

end tree;
/
