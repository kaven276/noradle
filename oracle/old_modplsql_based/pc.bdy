create or replace package body pc is

	-- private
	function md5(ns varchar2, cid varchar2) return dbms_obfuscation_toolkit.varchar2_checksum is
	begin
		return dbms_obfuscation_toolkit.md5(input_string => ns || '.' || cid);
	end;

	function changed(p_namespace varchar2, p_cache_id in out nocopy varchar2, p_this_id varchar2) return boolean is
		v_msg varchar2(1);
		v_rtn pls_integer;
		procedure signal(p_state varchar2) is
		begin
			return;
			dbms_alert.signal('pc:' || p_namespace,
												rpad(sys_context('userenv', 'SID'), 5) || p_state || ' : ' || p_this_id || ' @ ' || r.prog);
		end;
	begin
		if p_cache_id is null or p_cache_id != p_this_id then
			-- 如果 package cache 空或发生标识切换
			if p_cache_id is not null then
				dbms_alert.remove(md5(p_namespace, p_cache_id));
				signal('switch');
			else
				signal('init   ');
			end if;
			p_cache_id := p_this_id;
			begin
				dbms_alert.register(md5(p_namespace, p_cache_id));
			exception
				when others then
					dbms_alert.remove(md5(p_namespace, p_cache_id));
					dbms_alert.register(md5(p_namespace, p_cache_id));
			end;
			return true;
		else
			dbms_alert.waitone(md5(p_namespace, p_this_id), v_msg, v_rtn, 0);
			if v_rtn = 0 then
				signal('update');
				return true;
			elsif v_rtn = 1 then
				signal('hit   ');
				return false;
			else
				raise_application_error(-20990, 'package cache error');
			end if;
		
		end if;
	end;

	procedure change(p_namespace varchar2, p_cache_id varchar2) is
	begin
		dbms_alert.signal(md5(p_namespace, p_cache_id), '');
	end;

end pc;
/

