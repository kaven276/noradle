create or replace package k_cfg_reader is

	function find_prefix
	(
		p_dbu varchar2,
		p_key varchar2
	) return varchar2 result_cache;

end k_cfg_reader;
/
