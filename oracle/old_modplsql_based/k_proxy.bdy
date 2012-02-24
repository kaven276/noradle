create or replace package body k_proxy is

	-- Refactored procedure send_command
	function send_command
	(
		p_src_url varchar2,
		p_js_url  varchar2,
		p_cb_url  varchar2 := null
	) return number is
		v_result    number;
		v_pipe_name varchar2(100) := dbms_pipe.unique_session_name;

	begin
		--dbms_pipe.purge(v_pipe_name|| '#send');
		dbms_pipe.pack_message(p_src_url);

		-- js url
		declare
			v_js_url varchar2(1000);
		begin
			if p_js_url like 'u:%' then
				v_js_url := u(substr(p_js_url, 3));
			else
				v_js_url := p_js_url;
			end if;
			if v_js_url not like '/%' and v_js_url not like 'http%' then
				v_js_url := owa_util.get_cgi_env('SCRIPT_NAME') || '/' || v_js_url;
			end if;
			dbms_pipe.pack_message(v_js_url);
		end;

		-- cb url
		declare
			v_cb_url varchar2(1000);
		begin
			if p_cb_url is null then
				v_cb_url := 'http://localhost/psp.web/psp/!proxy_b.processor';
			else
				if p_cb_url like 'u:%' then
					v_cb_url := u(substr(p_cb_url, 3));
				else
					v_cb_url := p_cb_url;
				end if;
			end if;
			if v_cb_url not like '/%' and v_cb_url not like 'http%' then
				v_cb_url := owa_util.get_cgi_env('SCRIPT_NAME') || '/' || v_cb_url;
			end if;
			dbms_pipe.pack_message(v_cb_url);
		end;

		v_result := dbms_pipe.send_message(v_pipe_name || '#send');
		dbms_alert.signal('proxy_req', v_pipe_name);
		commit;
		return v_result;
	end send_command;

end k_proxy;
/

