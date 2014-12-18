create or replace package auth_b is

	procedure basic;

	procedure digest;

	procedure cookie_gac;

	procedure login;

	procedure logout;

	procedure protected_page;

	procedure basic_and_cookie;

	procedure logout_basic;

	procedure check_update;

end auth_b;
/
