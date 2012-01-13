create or replace package body k_cfg_reader is

	function find_prefix(p_dbu varchar2, p_key varchar2) return varchar2 result_cache relies_on(ext_url_t) is
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
					raise_application_error(-20000, 'no such url prefix for key : ' || p_key);
			end;
	end;

	function front_server_ip return varchar2 is
	begin
		return '61.181.22.72';
	end;

	function front_server_prefix return varchar2 is
	begin
		return null;
	end;

end k_cfg_reader;
/

