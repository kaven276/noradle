create or replace package body profile_s is

	procedure set_scheme(name varchar2) is
	begin
		r.session('pf.scheme', name);
	end;

	function get_scheme return varchar2 is
	begin
		return r.session('pf.scheme');
	end;

	procedure set_rows_per_page(rows number) is
	begin
		r.session('pf.rows', rows);
	end;

	function get_rows_per_page return number is
	begin
		return r.session('pf.rows');
	end;

end profile_s;
/
