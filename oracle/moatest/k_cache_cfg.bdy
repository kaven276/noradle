create or replace package body k_cache_cfg is

	-- private
	function max_age(p_db_user varchar2, p_mime_type varchar2) return number result_cache relies_on(cache_cfg_t) is
		v_max_age cache_cfg_t.max_age%type;
	begin
		select *
			into v_max_age
			from (select a.max_age
							from cache_cfg_t a
						 where a.db_user = p_db_user
							 and p_mime_type like a.mime_type
						 order by lengthb(a.mime_type) desc)
		 where rownum = 1;
		return v_max_age;
	exception
		when no_data_found then
			begin
				select *
					into v_max_age
					from (select a.max_age
									from cache_cfg_t a
								 where a.db_user = 'psp'
									 and p_mime_type like a.mime_type
								 order by lengthb(a.mime_type) desc)
				 where rownum = 1;
				return v_max_age;
			exception
				when no_data_found then
					return 2; -- 没有任何配置，默认为 expire 2 分钟
			end;
	end;

	function max_age(p_mime_type varchar2) return number is
	begin
		return max_age(r.dbu, p_mime_type);
	end;

	-- private
	function safe_time(p_db_user varchar2) return date result_cache relies_on(dad_t) is
		v_date date;
	begin
		select max(a.safe_time) into v_date from dad_t a where a.db_user = p_db_user;
		return v_date;
	end;

	function safe_time return date is
		v_date date;
	begin
		return safe_time(r.dbu);
	end;

	-- gac 缓存的最后更新时间是否是通过xml-db event立即更新
	function instant_gac return boolean is
	begin
		return false;
	end;

end k_cache_cfg;
/

