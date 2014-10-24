create or replace package body k_auth is

	gc_dfmt constant varchar2(16) := 'YYYYMMDDHH24MISS';

	procedure attr
	(
		name  varchar2,
		value varchar2
	) is
	begin
		e.chk(user_id is null, -20022, 'session attr must be set in logged-in status');
		r.setc('s$' || name, value);
	end;

	function attr(name varchar2) return varchar2 is
	begin
		return r.getc('s$' || name);
	end;

	procedure login
	(
		uid    varchar2,
		gid    varchar2 := null,
		method varchar2 := null
	) is
	begin
		r.setc('s$UID', uid);
		r.setd('s$LTIME', sysdate);
		r.setd('s$LAT', sysdate);
		r.setc('s$GID', gid);
		r.setc('s$METHOD', method);
	end;

	procedure logout is
	begin
		r.setc('s$BSID', '');
	end;

	function user_id return varchar2 is
	begin
		return r.getc('s$UID');
	end;

	function group_id return varchar2 is
	begin
		return r.getc('s$GID');
	end;

	function uid return varchar2 is
	begin
		return r.getc('s$UID');
	end;

	function gid return varchar2 is
	begin
		return r.getc('s$GID');
	end;

	function logged return boolean is
	begin
		return user_id is not null;
	end;

	function login_time return date is
	begin
		return r.getd('LTIME');
	end;

	function last_access_time return date is
	begin
		return sysdate - r.getn('s$IDLE') / 1000 / 24 / 60 / 60;
	end;

	function lat return date is
	begin
		return sysdate - r.getn('s$IDLE') / 1000 / 24 / 60 / 60;
	end;

end k_auth;
/
