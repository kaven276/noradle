create or replace package body k_cfg is

	function server_control return server_control_t%rowtype result_cache relies_on(server_control_t) is
		v server_control_t%rowtype;
	begin
		select * into v from server_control_t where rownum = 1;
		return v;
	exception
		when no_data_found then
			e.chk(true, -20015, 'No configuation data in PSP.WEB''s server_control_t table');
	end;

	function find_prefix
	(
		p_dbu varchar2,
		p_key varchar2
	) return varchar2 result_cache relies_on(ext_url_t) is
		v_prefix ext_url_t.prefix%type;
	begin
		select a.prefix
			into v_prefix
			from ext_url_t a
		 where a.dbu = lower(p_dbu)
			 and a.key = p_key;
		return v_prefix;
	exception
		when no_data_found then
			begin
				select a.prefix
					into v_prefix
					from ext_url_t a
				 where a.dbu = 'psp'
					 and a.key = p_key;
				return v_prefix;
			exception
				when no_data_found then
					e.raise(-20017, 'no such url prefix for key : ' || p_key);
			end;
	end;

end k_cfg;
/
