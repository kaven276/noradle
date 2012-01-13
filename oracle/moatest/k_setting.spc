create or replace package k_setting is

	function db_char_set return varchar2 result_cache;

	function psp_dad_path return varchar2;

end k_setting;
/

