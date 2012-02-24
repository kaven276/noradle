create or replace package k_cfg is

	function server_control return server_control_t%rowtype result_cache;

end k_cfg;
/
