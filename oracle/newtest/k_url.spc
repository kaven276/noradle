create or replace package k_url authid current_user is

	function normalize(url varchar2, proc boolean := true) return varchar2;

end k_url;
/
