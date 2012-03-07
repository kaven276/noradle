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
		dbms_session.set_identifier(sys_context('userenv', 'current_schema') || '#' || type);
		k_gac.gset('KEY_VER_CTX', key, ver);
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
		dbms_session.set_identifier(sys_context('userenv', 'current_schema') || '#' || type);
		k_gac.grm('KEY_VER_CTX', key);
		dbms_session.set_identifier(v_cid);
	end;

	function get
	(
		type varchar2,
		key  varchar2
	) return varchar2 is
		v_cid varchar2(64);
		v_ver varchar2(99);
	begin
		v_cid := sys_context('user', 'client_identifier', 64);
		dbms_session.set_identifier(sys_context('userenv', 'current_schema') || '#' || type);
		v_ver := sys_context('KEY_VER_CTX', key);
		dbms_session.set_identifier(v_cid);
		return v_ver;
	end;

end kv;
/
