create or replace package body k_auth is

	gc_dfmt constant varchar2(16) := 'YYYYMMDDHH24MISS';

	procedure attr
	(
		name  varchar2,
		value varchar2
	) is
	begin
		e.chk(user_id is null, -20022, 'session attr must be set in logged-in status');
		r.s(name, value);
	end;

	function attr(name varchar2) return varchar2 is
	begin
		return r.s(name);
	end;

	procedure login
	(
		uid    varchar2,
		gid    varchar2 := null,
		method varchar2 := null
	) is
	begin
		r.s('UID', uid);
		r.s('LTIME', to_char(sysdate, gc_dfmt));
		r.s('LAT', to_char(sysdate, gc_dfmt));
		if gid is not null then
			r.s('GID', gid);
		end if;
		if method is not null then
			r.s('METHOD', method);
		end if;
	end;

	procedure logout is
	begin
		r.s('BSID', '');
	end;

	function user_id return varchar2 is
	begin
		return r.s('UID');
	end;

	function group_id return varchar2 is
	begin
		return r.s('GID');
	end;

	function uid return varchar2 is
	begin
		return r.s('UID');
	end;

	function gid return varchar2 is
	begin
		return r.s('GID');
	end;

	function logged return boolean is
	begin
		return user_id is not null;
	end;

	function login_time return date is
	begin
		return to_date(r.s('LTIME'), gc_dfmt);
	end;

	function last_access_time return date is
	begin
		return to_date(r.s('LAT'), gc_dfmt);
	end;

	function lat return date is
	begin
		return to_date(r.s('LAT'), gc_dfmt);
	end;

end k_auth;
/
