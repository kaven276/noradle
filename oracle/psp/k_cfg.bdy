create or replace package body k_cfg is

	type svr_ctl_map is table of server_control_t%rowtype index by varchar2(15);

	function server_controls return svr_ctl_map result_cache relies_on(server_control_t) is
		v svr_ctl_map;
	begin
		for i in (select a.* from server_control_t a) loop
			v(upper(i.cfg_id)) := i;
		end loop;
		return v;
	end;

	function server_control return server_control_t%rowtype is
	begin
		return server_controls()(nvl(pv.cfg_id, 'default'));
	exception
		when no_data_found then
			e.chk(true, -20015, 'No configuation data in PSP.WEB''s server_control_t table');
	end;

	function find_prefix
	(
		p_dbu varchar2,
		p_key varchar2,
		p_prt varchar2
	) return varchar2 result_cache relies_on(ext_url_t) is
		v ext_url_t%rowtype;
	begin
		begin
			select a.*
				into v
				from ext_url_t a
			 where a.dbu = lower(p_dbu)
				 and a.key = p_key;
		exception
			when no_data_found then
				begin
					select a.*
						into v
						from ext_url_t a
					 where a.dbu = '/'
						 and a.key = p_key;
				exception
					when no_data_found then
						e.raise(-20017,
										'no such url prefix for key : ' || p_key || ', please config ext_url_v for external url reference.');
				end;
		end;
		case p_prt
			when 'http' then
				return nvl(v.prefix, v.prefix_https);
			when 'https' then
				return nvl(v.prefix_https, v.prefix);
		end case;
	end;

	function find_prefix
	(
		p_dbu varchar2,
		p_key varchar2
	) return varchar2 is
	begin
		return find_prefix(p_dbu, p_key, r.protocol);
	end;

	function get_ext_fs return varchar2 is
	begin
		return server_control().static_url;
	end;

end k_cfg;
/
