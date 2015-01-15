create or replace package body k_cfg is

	function server_control(p_cfg_id varchar2) return server_control_t%rowtype result_cache relies_on(server_control_t) is
		v server_control_t%rowtype;
	begin
		select a.* into v from server_control_t a where a.cfg_id = p_cfg_id;
		return v;
	exception
		when no_data_found then
			e.chk(true, -20015, 'No configuation data in PSP.WEB''s server_control_t table for ' || pv.cfg_id);
	end;

	procedure server_control(p_cfg in out nocopy server_control_t%rowtype) is
	begin
		p_cfg := server_control(nvl(pv.cfg_id, 'default'));
	end;

end k_cfg;
/
