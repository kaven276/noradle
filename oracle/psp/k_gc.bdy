create or replace package body k_gc is

	procedure login_session is
		v_thres date := sysdate - 1 / 24 / 60;
	begin
		for i in (select * from global_context a where a.namespace = 'SESS_CID_CTX') loop
			if to_date(substrb(i.value, 16, 15), pv.gac_dtfmt) < v_thres then
				dbms_session.set_identifier(i.attribute);
				k_gac.grm('SESS_ATTR_CTX');
				dbms_session.clear_identifier;
				k_gac.grm('SESS_CID_CTX', i.attribute);
			end if;
		end loop;
	end;

end k_gc;
/
