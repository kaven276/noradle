create or replace package body tree is

	procedure content
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

end tree;
/
