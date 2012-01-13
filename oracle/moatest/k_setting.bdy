create or replace package body k_setting is

	function db_char_set return varchar2 result_cache is
		v_charset varchar2(30);
	begin
		select a.property_value
			into v_charset
			from database_properties a
		 where a.property_name = 'NLS_CHARACTERSET';
		return v_charset;
	end;

	function psp_dad_path return varchar2 is
	begin
		return '/psp';
	end;

end k_setting;
/

