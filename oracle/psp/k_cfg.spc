create or replace package k_cfg is

	function server_control return server_control_t%rowtype;

	function find_prefix
	(
		p_dbu varchar2,
		p_key varchar2
	) return varchar2;

	function get_ext_fs return varchar2;

end k_cfg;
/
