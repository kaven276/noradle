create or replace package body k_gen_code is

	procedure form_items
	(
		p_sql     varchar2,
		p_varname varchar2
	) is
		c       integer;
		col_cnt integer;
		desc_t  dbms_sql.desc_tab;
		col_num integer;
		procedure print_rec(rec in dbms_sql.desc_rec) is
		begin
			dbms_output.put_line(nvl(p_varname, 'y_comp.form_item') ||
													 replace(('(v.~, ''p_~'', ''~'');'), '~', lower(rec.col_name)));
		end;
	begin
		c := dbms_sql.open_cursor;
		dbms_sql.parse(c, p_sql, dbms_sql.native);
		dbms_sql.describe_columns(c, col_cnt, desc_t);
		col_num := desc_t.first;
		if (col_num is not null) then
			loop
				print_rec(desc_t(col_num));
				col_num := desc_t.next(col_num);
				exit when(col_num is null);
			end loop;
		end if;
		dbms_sql.close_cursor(c);
	end;

	procedure table_list
	(
		p_sql     varchar2,
		p_varname varchar2
	) is
		c       integer;
		col_cnt integer;
		desc_t  dbms_sql.desc_tab3;
		col_num integer;

		procedure add_item(rec in dbms_sql.desc_rec3) is
			v_align varchar2(10);
			v_width varchar2(10);
		begin
			case
				when rec.col_type in (1, 12) then
					--('CHAR', 'NCHAR', 'DATE')
					v_align := 'center';
				when rec.col_type in (1) then
					-- ('VARCHAR2', 'NVARCHAR2')
					v_align := 'left';
				when rec.col_type in (2) then
					--  ('NUMBER')
					v_align := 'right';
				else
					v_align := '';
			end case;
			if rec.col_type = 12 then
				v_width := '20ex';
			else
				v_width := (rec.col_max_len) || 'ex';
			end if;

			dbms_output.put_line(nvl(p_varname, 'v_cfg') ||
													 p.ps('.add_item('':1'', '':2'', '':3'', '':4'');',
																			st(lower(rec.col_name), lower(rec.col_name), v_align, v_width)));
		end;

		procedure tds(rec in dbms_sql.desc_rec3) is
			v_align varchar2(10);
			v_width varchar2(10);
		begin
			case
				when rec.col_type in (1, 12) then
					--('CHAR', 'NCHAR', 'DATE')
					v_align := 'center';
				when rec.col_type in (1) then
					-- ('VARCHAR2', 'NVARCHAR2')
					v_align := 'left';
				when rec.col_type in (2) then
					--  ('NUMBER')
					v_align := 'right';
				else
					v_align := '';
			end case;
			if rec.col_type = 12 then
				v_width := '20ex';
			else
				v_width := (rec.col_max_len) || 'ex';
			end if;

			dbms_output.put_line(nvl(p_varname, 'v_cfg') ||
													 p.ps('.add_item('':1'', '':2'', '':3'', '':4'');',
																			st(lower(rec.col_name), lower(rec.col_name), v_align, v_width)));
		end;

	begin
		c := dbms_sql.open_cursor;
		dbms_sql.parse(c, p_sql, dbms_sql.native);
		dbms_sql.describe_columns3(c, col_cnt, desc_t);
		col_num := desc_t.first;
		if (col_num is not null) then
			loop
				add_item(desc_t(col_num));
				col_num := desc_t.next(col_num);
				exit when(col_num is null);
			end loop;
		end if;
		col_num := desc_t.first;
		if (col_num is not null) then
			loop
				tds(desc_t(col_num));
				col_num := desc_t.next(col_num);
				exit when(col_num is null);
			end loop;
		end if;
		dbms_sql.close_cursor(c);
	end;

end k_gen_code;
/

