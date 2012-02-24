create or replace package k_cookie is

	function get(p_name varchar2) return varchar2;

	procedure install(p_name varchar2, p_value varchar2);

	-- public
	procedure send(p_name varchar2, p_value varchar2);

	procedure set_expire(p_name varchar2, p_date date);

	procedure set_max_age(p_name varchar2, p_age number);

	procedure remove(p_name varchar2, p_value varchar2);

end k_cookie;
/

