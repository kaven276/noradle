create or replace package body list is

	-- table cfg
	gv_class      st;
	gv_label      st;
	gv_align      st;
	gv_width      st;
	gv_style      st;
	gv_format     st;
	gv_item_count integer;

	procedure cfg_init(lcss_ctx varchar2) is
	begin
		gv_class      := st();
		gv_label      := st();
		gv_align      := st();
		gv_width      := st();
		gv_style      := st();
		gv_format     := st();
		gv_item_count := 0;
		style.lcss_ctx(lcss_ctx);
	end;

	procedure cfg_add
	(
		class  varchar2,
		label  varchar2,
		align  varchar2 := 'center',
		width  varchar2 := null,
		style  varchar2 := null,
		format varchar2 := null
	) is
		i integer;
	begin
		gv_item_count := gv_item_count + 1;
		i             := gv_item_count;
		gv_class.extend;
		gv_label.extend;
		gv_align.extend;
		gv_width.extend;
		gv_style.extend;
		gv_format.extend;
		gv_class(i) := class;
		gv_label(i) := label;
		gv_align(i) := align;
		gv_width(i) := width;
		gv_style(i) := style;
		gv_format(i) := format;
	end;

	procedure cfg_cols is
	begin
		for i in 1 .. gv_item_count loop
			if gv_width(i) is not null then
				x.s('<col.:1 style=width::2>', st(gv_class(i), gv_width(i)));
			else
				x.s('<col.:1>', st(gv_class(i)));
			end if;
		end loop;
	end;

	procedure cfg_css is
		v_sel varchar2(1000) := '>tbody>tr>td:nth-child(';
		v_css varchar2(1000);
	begin
		for i in 1 .. gv_item_count loop
			v_css := gv_style(i);
			if gv_align(i) is not null then
				v_css := v_css || 'text-align:' || gv_align(i) || ';';
			end if;
			style.lcss(v_sel || i || ') { ' || v_css || ' }');
		end loop;
	end;

	procedure cfg_ths is
	begin
		for i in 1 .. gv_item_count loop
			x.p('<th>', gv_label(i));
		end loop;
	end;

	procedure cfg_cols_thead is
	begin
		cfg_css;
		cfg_cols;
		x.o('<thead>');
		x.o('<tr>');
		cfg_ths;
		x.c('</tr>');
		x.c('</thead>');
	end;

	procedure cfg_content
	(
		cur        in out nocopy sys_refcursor,
		fmt_date   varchar2 := null,
		group_size pls_integer := null,
		flush      pls_integer := null
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
		v_grp_cnt  pls_integer := 0;
		v_row_cnt  pls_integer := 0;
		procedure set_align
		(
			p_align varchar2,
			i       pls_integer
		) is
		begin
			if gv_align(i) is null then
				gv_align(i) := p_align;
			end if;
		end;
	begin
		curid := dbms_sql.to_cursor_number(cur);
		dbms_sql.describe_columns(curid, colcnt, desctab);
	
		for i in 1 .. colcnt loop
			case desctab(i).col_type
				when 1 then
					dbms_sql.define_column(curid, i, v_varchar2, 2000);
					set_align('left', i);
				when 2 then
					dbms_sql.define_column(curid, i, v_number);
					set_align('right', i);
				when 12 then
					dbms_sql.define_column(curid, i, v_date);
					set_align('center', i);
				else
					dbms_sql.define_column(curid, i, v_other, 2000);
					set_align('center', i);
			end case;
			v_col_name := lower(desctab(i).col_name);
			v_collen   := desctab(i).col_max_len;
			x.s('<col.pwc_:1 style=width::2>', st(v_col_name, nvl(gv_width(i), v_collen || 'ex')));
		end loop;
	
		-- set tbody cols css
		cfg_css;
	
		-- thead label use cfg or alias
		x.o('<thead>');
		x.o('<tr>');
		for i in 1 .. gv_item_count loop
			x.p('<th>', nvl(gv_label(i), desctab(i).col_name));
		end loop;
		x.c('</tr>');
		x.c('</thead>');
	
		-- Fetch Rows
		x.o('<tbody>');
		v_row_cnt := 0;
		while dbms_sql.fetch_rows(curid) > 0 loop
			v_row_cnt := v_row_cnt + 1;
			x.o('<tr>');
			for i in 1 .. colcnt loop
				case desctab(i).col_type
					when 1 then
						dbms_sql.column_value(curid, i, v_varchar2);
						x.p('<td>', v_varchar2);
					when 2 then
						dbms_sql.column_value(curid, i, v_number);
						if gv_format(i) is not null then
							x.p('<td>', to_char(v_number, gv_format(i)));
						else
							x.p('<td>', to_char(v_number));
						end if;
					when 12 then
						dbms_sql.column_value(curid, i, v_date);
						x.p('<td>', to_char(v_date, coalesce(gv_format(i), fmt_date, 'yyyy-mm-dd')));
					else
						dbms_sql.column_value(curid, i, v_other);
						x.p('<td>', v_other);
				end case;
			end loop;
			x.c('</tr>');
			if group_size is not null then
				v_grp_cnt := v_grp_cnt + 1;
				if v_grp_cnt = group_size then
					v_grp_cnt := 0;
					x.t('</tbody><tbody>');
				end if;
			end if;
			if flush is not null and mod(v_row_cnt, flush) = 0 then
				h.flush;
			end if;
		end loop;
		x.c('</tbody>');
		tmp.rows := v_row_cnt;
		dbms_sql.close_cursor(curid);
	exception
		when no_data_found then
			x.c('<tbody>');
			tmp.rows := v_row_cnt;
			dbms_sql.close_cursor(curid);
	end;

	procedure cfg_cur
	(
		cur        in out nocopy sys_refcursor,
		fmt_date   varchar2 := null,
		group_size pls_integer := null,
		flush      pls_integer := null
	) is
	begin
		cfg_content(cur, fmt_date, group_size, flush);
	end;

end list;
/
