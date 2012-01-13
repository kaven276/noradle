create or replace package body k_auth is

	function do(procedure_name in varchar2) return boolean is
		v_judge boolean;
	begin
		dbms_session.clear_identifier;
		-- It's critical for security, psp req must go through !s, others will be forbidden
		if procedure_name != 's' then
			return false;
		end if;
		-- It's critical for right content, or may got previus req's result and cause mistake 
		-- and when sp dosn't gen content, it must has a blob of null
		if wpg_docload.v_blob is not null then
			-- raise_application_error(-20000, 'request begin with a none-empty wpg_docload.v_blob');
			if dbms_lob.istemporary(wpg_docload.v_blob) = 1 then
				dbms_lob.freetemporary(wpg_docload.v_blob);
			end if;
			wpg_docload.v_blob := null;
		end if;
		return true;
	end;

end k_auth;
/

