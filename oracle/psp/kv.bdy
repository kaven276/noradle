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
		v_val := sys_context('KEY_VER_CTX', v_hash);
		v_ver := substrb(v_val, 13);
		return v_ver;
	end;

	procedure clear is
	begin
		dbms_session.clear_all_context('KEY_VER_CTX');
	end;

	procedure clear_timeout is
		v_thres date := sysdate - 15 / 24 / 60;
	begin
		dbms_session.clear_identifier;
		for i in (select * from global_context a where a.namespace = 'KEY_VER_CTX') loop
			if to_date(substrb(i.value, 1, 12), pv.gac_dtfmt) < v_thres then
				k_gac.grm('KEY_VER_CTX', i.attribute);
			end if;
		end loop;
	end;

end kv;
/
