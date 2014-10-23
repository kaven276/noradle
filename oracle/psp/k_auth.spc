create or replace package k_auth is

	no_session_gac_found exception;
	pragma exception_init(no_session_gac_found, -20021);
	no_session_cookie_found exception;
	pragma exception_init(no_session_cookie_found, -20022);
	over_max_keep exception;
	pragma exception_init(over_max_keep, -20023);
	over_max_idle exception;
	pragma exception_init(over_max_idle, -20024);

	procedure attr
	(
		name  varchar2,
		value varchar2
	);
	function attr(name varchar2) return varchar2;

	procedure login
	(
		uid    varchar2,
		gid    varchar2 := null,
		method varchar2 := null
	);
	procedure logout;

	function logged return boolean;
	function user_id return varchar2;
	function group_id return varchar2;
	function uid return varchar2;
	function gid return varchar2;
	function login_time return date;
	function last_access_time return date;
	function lat return date;

end k_auth;
/
