create or replace package body k_sess is

	-- private
	function timestr(dt date := sysdate) return varchar2 is
	begin
		return to_char(dt, pv.gac_dtfmt);
	end;

	-- globall unique client id
	function gucid return varchar2 is
		v_guid raw(16);
	begin
		v_guid := dbms_crypto.hash(utl_raw.cast_from_number(gac_cid_seq.nextval), 1);
		return utl_raw.cast_to_varchar2(utl_encode.base64_encode(v_guid));
	end;

	procedure chk_max_keep(limit interval day to second) is
	begin
		if sysdate > login_time + limit then
			logout;
			raise over_max_keep;
		end if;
	end;

	procedure chk_max_idle(limit interval day to second) is
	begin
		if sysdate > last_access_time + limit then
			logout;
			raise over_max_idle;
		end if;
	end;

	function use_bsid_cookie
	(
		cookie varchar2 := null,
		domain varchar2 := null,
		path   varchar2 := 'APP',
		secure boolean := null
	) return varchar2 is
		v_cookie varchar2(30) := nvl(cookie, 'BSID');
		v_bsid   varchar(30) := r.cookie(v_cookie);
		v_domain varchar2(99) := domain;
		v_path   varchar2(999);
	begin
		if v_bsid is null then
			v_bsid := gucid;
			case upper(path)
				when 'APP' then
					v_path := t.nvl2(r.base, '/' || r.base) || '/' || r.dad;
				else
					v_path := path;
			end case;
			v_domain := domain;
			h.set_cookie(v_cookie, v_bsid, path => v_path, domain => v_domain, secure => secure);
		end if;
		return v_bsid;
	end;

	function use_msid_cookie
	(
		cookie varchar2 := null,
		domain varchar2 := null,
		path   varchar2 := 'APP',
		secure boolean := null
	) return varchar2 is
		v_cookie varchar2(30) := nvl(cookie, 'MSID');
		v_msid   varchar(30) := r.cookie(v_cookie);
		v_domain varchar2(99) := domain;
		v_path   varchar2(999);
	begin
		if v_msid is null then
			v_msid := gucid;
			case upper(path)
				when 'APP' then
					v_path := t.nvl2(r.base, '/' || r.base) || '/' || r.dad;
				else
					v_path := path;
			end case;
			v_domain := domain;
			h.set_cookie(v_cookie, v_msid, path => v_path, domain => v_domain, secure => secure, expires => sysdate + 360);
		end if;
		return v_msid;
	end;

	procedure use
	(
		cookie   varchar2 := null,
		domain   varchar2 := null,
		path     varchar2 := 'APP',
		secure   boolean := null,
		max_keep interval day to second := null,
		max_idle interval day to second := null
	) is
		v_cookie   varchar2(30) := nvl(cookie, 'BSID');
		v_bsid     varchar(30) := r.cookie(v_cookie);
		v_cid      varchar(30);
		v_domain   varchar2(99);
		v_path     varchar2(999);
		v_max_keep interval day to second(0) := nvl(max_keep, '+00 12:00:00');
		v_max_idle interval day to second(0) := nvl(max_idle, '+00 00:15:00');
		v_gac_val  varchar2(230);
	begin
		v_bsid := use_bsid_cookie('BSID');
		v_cid  := translate(v_bsid, pv.base64_cookie, pv.base64_gac);
		dbms_session.clear_identifier;
		v_gac_val := sys_context('SESS_CID_CTX', v_cid);
		if v_gac_val is not null then
			pv.ls_uid := substrb(v_gac_val, 31);
			pv.ls_lgt := to_date(substrb(v_gac_val, 1, 15), pv.gac_dtfmt);
			pv.ls_lat := to_date(substrb(v_gac_val, 16, 15), pv.gac_dtfmt);
			chk_max_keep(v_max_keep);
			chk_max_idle(v_max_idle);
			k_gac.gset('SESS_CID_CTX', v_cid, timestr(pv.ls_lgt) || timestr(sysdate) || pv.ls_uid);
		else
			pv.ls_uid := null;
			pv.ls_lgt := null;
			pv.ls_lat := null;
		end if;
		dbms_session.set_identifier(v_cid);
	end;

	function get_session_id return varchar2 is
	begin
		return sys_context('user', 'client_identifier', 64);
	end;

	procedure attr
	(
		name  varchar2,
		value varchar2
	) is
	begin
		e.chk(user_id is null, -20022, 'session attr must be set in logged-in status');
		k_gac.gset('SESS_ATTR_CTX', name, value);
	end;

	function attr(name varchar2) return varchar2 is
	begin
		return sys_context('SESS_ATTR_CTX', name);
	end;

	procedure login(uid varchar2) is
		v_cid varchar2(30);
	begin
		v_cid := get_session_id;
		dbms_session.clear_identifier;
		k_gac.gset('SESS_CID_CTX', v_cid, timestr || timestr || uid);
		dbms_session.set_identifier(v_cid);
	end;

	procedure logout is
		v_cid varchar2(30);
	begin
		k_gac.grm('SESS_ATTR_CTX');
		v_cid := get_session_id;
		dbms_session.clear_identifier;
		k_gac.grm('SESS_CID_CTX', v_cid);
		dbms_session.set_identifier(v_cid);
	end;

	function user_id return varchar2 is
	begin
		return pv.ls_uid;
	end;

	function login_time return date is
	begin
		return pv.ls_lgt;
	end;

	function last_access_time return date is
	begin
		return pv.ls_lat;
	end;

	procedure rm is
	begin
		k_gac.grm('SESS_ATTR_CTX');
	end;

end k_sess;
/
