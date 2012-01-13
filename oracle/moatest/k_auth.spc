create or replace package k_auth is

	function do(procedure_name in varchar2) return boolean;

end k_auth;
/

