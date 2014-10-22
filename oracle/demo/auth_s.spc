create or replace package auth_s is

	procedure login_simple(p_name varchar2);
	procedure login_complex(p_name varchar2);
	procedure logout;
	function user_name return varchar2;
	function login_time return date;

end auth_s;
/
