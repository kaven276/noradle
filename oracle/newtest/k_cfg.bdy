create or replace package body k_cfg is

	function server_control return server_control_t%rowtype result_cache relies_on(server_control_t) is
		v server_control_t%rowtype;
	begin
		select * into v from server_control_t where rownum = 1;
		return v;
	exception
		when no_data_found then
			e.chk(true, -20015, 'No configuation data in PSP.WEB''s server_control_t table');
	end;

end k_cfg;
/
