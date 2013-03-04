create or replace package body kv is

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
		k_gac.gset('KEY_VER_CTX',
							 hash(sys_context('userenv', 'current_schema'), type, key),
							 to_char(sysdate, pv.gac_dtfmt) || ver);
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
		k_gac.grm('KEY_VER_CTX', hash(sys_context('userenv', 'current_schema'), type, key));
		dbms_session.set_identifier(v_cid);
	end;

	function get
	(
		type varchar2,
		key  varchar2
	) return varchar2 is
		v_hash varchar2(30) := hash(sys_context('userenv', 'current_schema'), type, key);
		v_cid  varchar2(64);
		v_lat  date;
		v_val  varchar2(99);
		v_ver  varchar2(99);
	begin
		v_cid := sys_context('user', 'client_identifier', 64);
		dbms_session.clear_identifier;
		v_val := sys_context('KEY_VER_CTX', v_hash);
		v_lat := to_date(substrb(v_val, 1, 12), pv.gac_dtfmt);
		v_ver := substrb(v_val, 13);
		if v_lat + 10 / 24 / 60 < sysdate then
			k_gac.gset('KEY_VER_CTX', v_hash, to_char(sysdate, pv.gac_dtfmt) || v_ver);
		end if;
		dbms_session.set_identifier(v_cid);
		return v_ver;
	end;

	procedure clear is
	begin
		dbms_session.clear_all_context('KEY_VER_CTX');
	end;

end kv;
/
