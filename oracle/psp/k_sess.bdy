create or replace package body k_sess is

	gc_dfmt constant varchar2(16) := 'YYYYMMDDHH24MISS';

	-- private
	function ctx return varchar2 is
	begin
		return nvl(pv.ctx, 'A#' || upper(r.dbu));
	end;

	procedure attr
	(
		name  varchar2,
		value varchar2
	) is
	begin
		e.chk(user_id is null, -20022, 'session attr must be set in logged-in status');
		k_gac.gset(ctx, name, value);
	end;

	function attr(name varchar2) return varchar2 is
	begin
		return sys_context(ctx, name);
	end;

	procedure login
	(
		uid    varchar2,
		gid    varchar2 := null,
		method varchar2 := null
	) is
	begin
		k_gac.gset(ctx, 'UID', uid);
		k_gac.gset(ctx, 'LTIME', to_char(sysdate, gc_dfmt));
		k_gac.gset(ctx, 'LAT', to_char(sysdate, gc_dfmt));
		if gid is not null then
			k_gac.gset(ctx, 'GID', gid);
		end if;
		if method is not null then
			k_gac.gset(ctx, 'METHOD', method);
		end if;
	end;

	procedure logout is
	begin
		k_gac.grm(ctx);
	end;

	procedure touch is
	begin
		k_gac.gset(ctx, 'LAT', to_char(sysdate, gc_dfmt));
	end;

	function user_id return varchar2 is
	begin
		return sys_context(ctx, 'UID');
	end;

	function group_id return varchar2 is
	begin
		return sys_context(ctx, 'GID');
	end;

	function uid return varchar2 is
	begin
		return sys_context(ctx, 'UID');
	end;

	function gid return varchar2 is
	begin
		return sys_context(ctx, 'GID');
	end;

	function logged return boolean is
	begin
		return user_id is not null;
	end;

	function login_time return date is
	begin
		return to_date(sys_context(ctx, 'LTIME'), gc_dfmt);
	end;

	function last_access_time return date is
	begin
		return to_date(sys_context(ctx, 'LAT'), gc_dfmt);
	end;

	function lat return date is
	begin
		return to_date(sys_context(ctx, 'LAT'), gc_dfmt);
	end;

	procedure rm is
	begin
		k_gac.grm(ctx);
	end;

	procedure use_ctx(ctx varchar2) is
	begin
		pv.ctx := ctx;
	end;

end k_sess;
/
