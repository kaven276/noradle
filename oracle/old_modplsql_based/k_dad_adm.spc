create or replace package k_dad_adm is

	procedure create_dad(p_dad_name varchar2, p_db_user varchar2);

	procedure drop_dad(p_dad_name varchar2);

	procedure create_repo(p_dad_name varchar2, p_db_user varchar2 := null, p_link_dad_name varchar2 := null);

	function map_dbuser(p_dadname varchar2) return varchar2 result_cache;

end k_dad_adm;
/

