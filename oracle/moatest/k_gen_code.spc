create or replace package k_gen_code authid current_user is

	procedure form_items
	(
		p_sql     varchar2,
		p_varname varchar2
	);

	procedure table_list
	(
		p_sql     varchar2,
		p_varname varchar2
	);

end k_gen_code;
/

