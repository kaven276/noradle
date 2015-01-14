create or replace package result_cache_b is

	function get_user(p_name varchar2) return user_t%rowtype result_cache;

	procedure print_user;

	procedure output_user;

end result_cache_b;
/
