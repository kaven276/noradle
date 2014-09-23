create or replace package auth_s is

	procedure login_simple(p_name varchar2);
	procedure login_complex(p_name varchar2);
	procedure logout;
	procedure touch;
	procedure clear(ns varchar2);

end auth_s;
/
