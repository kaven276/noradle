create or replace package body k_gc is

	type ns_pack_t is table of varchar2(61) index by varchar2(30);

	procedure touch(bsid varchar2) is
		v_bsid varchar2(30) := translate(bsid, pv.base64_cookie, pv.base64_gac);
		v_val  varchar2(30);
		v_now  varchar2(15) := to_char(sysdate, pv.gac_dtfmt);
		v_lat  varchar2(12);
		v_idle boolean;
	begin
		dbms_session.clear_identifier;
		if bsid is null then
			return;
		end if;
		v_val := sys_context('SESS_CID_CTX', v_bsid);
		if v_val is null then
			-- create session log
			dbms_session.set_context('SESS_CID_CTX', v_bsid, v_now || v_now);
		else
			-- update session LAT only if minute change, to avoid frequent GAC update
			v_lat := substr(v_val, 13, 24);
			if v_now != v_lat then
				v_idle := sysdate - to_date(v_lat, pv.gac_dtfmt) > 30 / 24 / 60;
				dbms_session.set_context('SESS_CID_CTX', v_bsid, substr(v_val, 1, 12) || v_now);
			end if;
		end if;
	
		dbms_session.set_identifier(bsid);
		pv.ctx := null;
	
		-- session timeout for system threshold
		if v_idle then
			for j in (select distinct a.namespace from global_context a where a.client_identifier is not null) loop
				for ns in (select a.namespace, a.schema || '.' || a.package as proc
										 from dba_context a
										where a.namespace = j.namespace) loop
					execute immediate 'call ' || ns.proc || '.clear()';
				end loop;
			end loop;
		end if;
	end;

	procedure clear_all_session is
	begin
		dbms_session.clear_all_context('SESS_CID_CTX');
	end;

	procedure login_session is
		v_thres date := sysdate - 1 / 2 / 24 / 60;
		v_cid   varchar2(30);
		v_sps   ns_pack_t;
	begin
		for ns in (select a.namespace, a.schema || '.' || a.package as proc
								 from dba_context a
								where a.type = 'ACCESSED GLOBALLY') loop
			v_sps(ns.namespace) := ns.proc;
		end loop;
		dbms_session.clear_identifier;
		for i in (select * from global_context a where a.namespace = 'SESS_CID_CTX') loop
			if to_date(substrb(i.value, 13, 12), pv.gac_dtfmt) < v_thres then
				v_cid := translate(i.attribute, pv.base64_gac, pv.base64_cookie);
				dbms_session.set_identifier(v_cid);
				for j in (select distinct a.namespace from global_context a where a.client_identifier is not null) loop
					execute immediate 'call ' || v_sps(j.namespace) || '.clear()';
				end loop;
			end if;
			dbms_session.clear_context('SESS_CID_CTX', null, i.attribute);
		end loop;
	end;

	procedure key_ver is
		v_thres date := sysdate - 15 / 24 / 60;
	begin
		dbms_session.clear_identifier;
		for i in (select * from global_context a where a.namespace = 'KEY_VER_CTX') loop
			if to_date(substrb(i.value, 1, 12), pv.gac_dtfmt) < v_thres then
				k_gac.grm('KEY_VER_CTX', i.attribute);
			end if;
		end loop;
	end;

end k_gc;
/
