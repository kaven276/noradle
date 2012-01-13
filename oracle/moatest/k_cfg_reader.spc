create or replace package k_cfg_reader is

	function find_prefix(p_dbu varchar2, p_key varchar2) return varchar2 result_cache;

	function front_server_ip return varchar2;

	function front_server_prefix return varchar2;

end k_cfg_reader;
/

