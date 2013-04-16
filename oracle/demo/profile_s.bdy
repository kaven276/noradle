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
		k_gac.gsetn(gc_ctx, 'rows', rows);
	end;

	function get_rows_per_page return number is
	begin
		return k_gac.getn(gc_ctx, 'rows');
	end;

	procedure clear is
	begin
		k_gac.grm(gc_ctx);
	end;

end profile_s;
/
