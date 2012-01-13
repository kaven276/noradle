create or replace function u(url varchar2, proc boolean := true) return varchar2 authid current_user is
begin
	return k_url.normalize(url, proc);
end u;
/

