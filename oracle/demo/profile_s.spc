create or replace package profile_s is

	procedure set_scheme(name varchar2);

	function get_scheme return varchar2;

	procedure set_rows_per_page(rows number);

	function get_rows_per_page return number;

end profile_s;
/
