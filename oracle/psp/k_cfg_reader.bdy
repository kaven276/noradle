create or replace package body k_cfg_reader is

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

end k_cfg_reader;
/
