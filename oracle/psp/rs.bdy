create or replace package body rs is

	procedure print
	(
		name varchar2,
		c    in out sys_refcursor
	) is
		curid   number;
		descrec dbms_sql.desc_rec;
		desctab dbms_sql.desc_tab;
		colcnt  number;
		namevar varchar2(4000);
		numvar  number;
		datevar date;
		vsize   number := 4000;
		sep     varchar2(2);
		lsep    varchar2(2) := chr(30) || chr(10);
		csep    varchar2(2) := chr(31) || ',';
	begin
		h.convert_json;
		h.write(lsep || '[' || name || ']' || lsep);
	
		-- Switch from native dynamic SQL to DBMS_SQL
		curid := dbms_sql.to_cursor_number(c);
	
		dbms_sql.describe_columns(curid, colcnt, desctab);
	
		-- Define columns
		sep := '';
		for i in 1 .. colcnt loop
			descrec := desctab(i);
			case descrec.col_type
				when 1 then
					dbms_sql.define_column(curid, i, namevar, vsize);
				when 2 then
					dbms_sql.define_column(curid, i, numvar);
				when 12 then
					dbms_sql.define_column(curid, i, datevar);
				else
					dbms_sql.define_column(curid, i, namevar, vsize);
			end case;
			h.write(sep || descrec.col_name || ':' || descrec.col_type);
			if i = 1 then
				sep := csep;
			end if;
		end loop;
	
		-- Fetch Rows
		while dbms_sql.fetch_rows(curid) > 0 loop
			sep := lsep;
			for i in 1 .. colcnt loop
				descrec := desctab(i);
				case descrec.col_type
					when 1 then
						dbms_sql.column_value(curid, i, namevar);
						h.write(sep || namevar);
					when 2 then
						dbms_sql.column_value(curid, i, numvar);
						h.write(sep || numvar);
					when 12 then
						dbms_sql.column_value(curid, i, datevar);
						h.write(sep || to_char(datevar, 'yyyy-mm-dd hh24:mi:ss'));
					else
						dbms_sql.column_value(curid, i, namevar);
						h.write(sep || namevar);
				end case;
				if i = 1 then
					sep := csep;
				end if;
			end loop;
		end loop;
		h.write(lsep);
	
		dbms_sql.close_cursor(curid);
	end;

	procedure print(c in out sys_refcursor) is
	begin
		print('data', c);
	end;

	procedure use_remarks is
	begin
		pv.nlbr := (chr(30) || chr(10));
	end;

end rs;
/
