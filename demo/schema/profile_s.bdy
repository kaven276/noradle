create or replace package body profile_s is

	procedure set_scheme(name varchar2) is
	begin
		r.setc('s$pf.scheme', name);
	end;

	function get_scheme return varchar2 is
	begin
		return r.getc('s$pf.scheme');
	end;

	procedure set_rows_per_page(rows number) is
	begin
		r.setn('s$pf.rows', rows);
	end;

	function get_rows_per_page return number is
	begin
		return r.getn('s$pf.rows');
	end;

end profile_s;
/
