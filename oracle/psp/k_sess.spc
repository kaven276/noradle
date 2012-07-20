create or replace package k_sess authid current_user is

	no_session_gac_found exception;
	pragma exception_init(no_session_gac_found, -20021);
	no_session_cookie_found exception;
	pragma exception_init(no_session_cookie_found, -20022);
	over_max_keep exception;
	pragma exception_init(over_max_keep, -20023);
	over_max_idle exception;
	pragma exception_init(over_max_idle, -20024);

	function gucid return varchar2;

	function use_bsid_cookie
	(
		cookie varchar2 := null,
		domain varchar2 := null,
		path   varchar2 := 'APP',
		secure boolean := null
	) return varchar2;

	function use_msid_cookie
	(
		cookie varchar2 := null,
		domain varchar2 := null,
		path   varchar2 := 'APP',
		secure boolean := null
	) return varchar2;

	procedure use
	(
		cookie   varchar2 := null,
		domain   varchar2 := null,
		path     varchar2 := 'APP',
		secure   boolean := null,
		max_keep interval day to second := null,
		max_idle interval day to second := null
	);

	function get_session_id return varchar2;

	procedure attr
	(
		name  varchar2,
		value varchar2
	);
	function attr(name varchar2) return varchar2;

	procedure login(uid varchar2);
	procedure logout;

	function user_id return varchar2;
	function login_time return date;
	function last_access_time return date;

	procedure chk_max_keep(limit interval day to second);
	procedure chk_max_idle(limit interval day to second);
	procedure rm;

end k_sess;
/
