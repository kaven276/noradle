create or replace package body kv is

	-- private
	function hash
	(
		type varchar2,
		key  varchar2
	) return varchar2 is
		v_gkey raw(999);
		v_hash varchar2(30);
	begin
		v_gkey := utl_raw.cast_to_raw(sys_context('userenv', 'current_schema') || '|' || type || '|' || key);
		v_hash := utl_raw.cast_to_varchar2(utl_encode.base64_encode(dbms_crypto.hash(v_gkey, 1)));
		return translate(v_hash, pv.base64_cookie, pv.base64_gac);
	end;

	procedure set
	(
		type varchar2,
		key  varchar2,
		ver  varchar2
	) is
		v_cid varchar2(64);
	begin
		v_cid := sys_context('user', 'client_identifier', 64);
		dbms_session.clear_identifier;
		k_gac.gset('KEY_VER_CTX', hash(type, key), to_char(sysdate, pv.gac_dtfmt) || ver);
		dbms_session.set_identifier(v_cid);
	end;

	procedure del
	(
		type varchar2,
		key  varchar2
	) is
		v_cid varchar2(64);
	begin
		v_cid := sys_context('user', 'client_identifier', 64);
		dbms_session.clear_identifier;
		k_gac.grm('KEY_VER_CTX', hash(type, key));
		dbms_session.set_identifier(v_cid);
	end;

	function get
	(
		type varchar2,
		key  varchar2
	) return varchar2 is
		v_hash varchar2(30) := hash(type, key);
		v_cid  varchar2(64);
		v_lat  date;
		v_val  varchar2(99);
		v_ver  varchar2(99);
	begin
		v_cid := sys_context('user', 'client_identifier', 64);
		dbms_session.clear_identifier;
		v_val := sys_context('KEY_VER_CTX', v_hash);
		v_lat := to_date(substrb(v_val, 1, 15), pv.gac_dtfmt);
		v_ver := substrb(v_val, 16);
		if v_lat + 10 / 24 / 60 < sysdate then
			k_gac.gset('KEY_VER_CTX', v_hash, to_char(sysdate, pv.gac_dtfmt) || v_ver);
		end if;
		dbms_session.set_identifier(v_cid);
		return v_ver;
	end;

end kv;
/
