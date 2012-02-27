create or replace package k_cfg is

	function server_control return server_control_t%rowtype result_cache;

	function find_prefix
	(
		p_dbu varchar2,
		p_key varchar2
	) return varchar2 result_cache;

end k_cfg;
/
