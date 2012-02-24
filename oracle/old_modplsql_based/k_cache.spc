create or replace package k_cache is
	pragma serially_reusable;

	gw constant varchar2(2) := 'GW';
	procedure init;

	procedure add_env(p_env varchar2);
	procedure set_gw_env;

	function need_vertime(p_max_age number := null) return boolean;

	procedure upt_time(p_time date);
	procedure upt_scn(p_scn number);
	procedure check_vertime;

	procedure auto_digest(p_max_age number := null);
	procedure server_expire(p_max_age number);

	procedure gw_after;

	procedure set_nocache(p_max_age number);
	procedure chk_set_nocache;
	procedure invalidate(url varchar2, para st := st());

	procedure log_chg_start;
	procedure log_chg_end;

end k_cache;
/

