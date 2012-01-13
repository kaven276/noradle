create or replace package k_file2 is

	-- Author  : ADMINISTRATOR
	-- Created : 2010-10-26 10:46:28
	-- Purpose :

	function get_fname(p_gw_name varchar2) return varchar2 deterministic;

	function get_name(p_gw_name varchar2) return varchar2 deterministic;

	function get_suffix(p_gw_name varchar2) return varchar2 deterministic;

	function seq_like_patten(p_gw_name varchar2) return varchar2 deterministic;

	function seq_extract_patten(p_gw_name varchar2) return varchar2 deterministic;

	function seq_value
	(
		p_gw_name   varchar2,
		p_comp_name varchar2
	) return varchar2 deterministic;

	procedure upload
	(
		p_name varchar2,
		p_blob in out nocopy blob
	);

	procedure ensure_folder(p_path varchar2);

	procedure place
	(
		p_gw_name varchar2,
		p_path    varchar2,
		p_name    varchar2
	);

	procedure place
	(
		p_gw_name varchar2,
		p_path    varchar2
	);

	procedure download;

end k_file2;
/

