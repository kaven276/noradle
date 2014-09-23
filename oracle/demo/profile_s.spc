create or replace package profile_s is

	procedure set_scheme(name varchar2);

	function get_scheme return varchar2;

	procedure set_rows_per_page(rows number);

	function get_rows_per_page return number;

	procedure clear(ns varchar2);

end profile_s;
/
