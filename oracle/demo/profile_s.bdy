create or replace package body profile_s is

	gc_ctx varchar2(30) := 'DEMO_PROFILE';

	procedure set_scheme(name varchar2) is
	begin
		k_gac.gset(gc_ctx, 'scheme', name);
	end;

	function get_scheme return varchar2 is
	begin
		return k_gac.get(gc_ctx, 'scheme');
	end;

	procedure set_rows_per_page(rows number) is
	begin
		k_gac.gset(gc_ctx, 'rows', to_char(rows));
	end;

	function get_rows_per_page return number is
	begin
		return to_number(k_gac.get(gc_ctx, 'rows'));
	end;

	procedure clear is
	begin
		k_gac.grm(gc_ctx);
	end;

end profile_s;
/
