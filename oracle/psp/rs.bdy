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
		if r.is_lack('z$array') then
			print('$DATA', c);
		else
			h.header('x-nd-z$array', r.getc('z$array'));
			if r.getc('z$array') = 'true' then
				print('$OBJECTS', c);
			else
				print('$OBJECT', c);
			end if;
		end if;
	
	end;

	procedure json(c in out sys_refcursor) is
		curid   number;
		descrec dbms_sql.desc_rec;
		desctab dbms_sql.desc_tab;
		colcnt  number;
		namevar varchar2(4000);
		numvar  number;
		datevar date;
		vsize   number := 4000;
		sep     varchar2(2);
		fstline boolean := true;
		line    varchar2(4000);
	begin
		-- Switch from native dynamic SQL to DBMS_SQL
		curid := dbms_sql.to_cursor_number(c);
	
		dbms_sql.describe_columns(curid, colcnt, desctab);
	
		-- Define columns
		for i in 1 .. colcnt loop
			descrec := desctab(i);
			if descrec.col_type in (1, 96) then
				dbms_sql.define_column(curid, i, namevar, vsize);
			elsif descrec.col_type in (2, 10, 101) then
				dbms_sql.define_column(curid, i, numvar);
			elsif descrec.col_type in (12) then
				dbms_sql.define_column(curid, i, datevar);
			else
				dbms_sql.define_column(curid, i, namevar, vsize);
			end if;
			desctab(i).col_name := lower(descrec.col_name);
		end loop;
	
		-- Fetch Rows
		while dbms_sql.fetch_rows(curid) > 0 loop
			if fstline then
				fstline := false;
				h.write('[{');
			else
				h.write(',{');
			end if;
		
			sep := '"';
			for i in 1 .. colcnt loop
				descrec := desctab(i);
				if descrec.col_type in (1, 96) then
					dbms_sql.column_value(curid, i, namevar);
					h.write(sep || descrec.col_name || '":"' || namevar || '"');
				elsif descrec.col_type in (2, 10, 101) then
					dbms_sql.column_value(curid, i, numvar);
					h.write(sep || descrec.col_name || '":' || numvar);
				elsif descrec.col_type in (12) then
					h.write(sep || descrec.col_name || '":"' || to_char(datevar, 'yyyy-mm-dd hh24:mi:ss') || '"');
				else
					dbms_sql.column_value(curid, i, namevar);
					h.write(sep || descrec.col_name || '":"' || namevar || '"');
				end if;
				if i = 1 then
					sep := ',"';
				end if;
			end loop;
			h.writeln('}');
		end loop;
		h.write(']');
	
		dbms_sql.close_cursor(curid);
	end;

	procedure use_remarks is
	begin
		pv.nlbr := (chr(30) || chr(10));
	end;

	procedure nv
	(
		n varchar2,
		t varchar2,
		v varchar2
	) is
		lsep  varchar2(2) := chr(30) || chr(10);
		nvsep varchar2(2) := chr(31) || '=';
	begin
		h.write(lsep || '*' || t || '|' || n || nvsep || v || lsep);
	end;

	procedure nv
	(
		n varchar2,
		v varchar2
	) is
	begin
		nv(n, 's', v);
	end;

	procedure nv
	(
		n varchar2,
		v number
	) is
	begin
		nv(n, 'n', to_char(v));
	end;

	procedure nv
	(
		n varchar2,
		v date
	) is
	begin
		nv(n, 'd', to_char(v, 'yyyy-mm-dd hh24:mi:ss'));
	end;

	procedure nv
	(
		n varchar2,
		v boolean
	) is
	begin
		nv(n, 'b', t.tf(v, 'T', 'F'));
	end;

end rs;
/
