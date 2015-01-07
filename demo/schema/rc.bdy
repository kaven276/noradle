create or replace package body rc is

	not_match exception;

	procedure set_user_info(p_username varchar2) is
		v_time date;
		function rc2row
		(
			key varchar2,
			ver date
		) return user_t%rowtype result_cache is
		begin
			if rcpv.user_hit then
				raise not_match;
			else
				return rcpv.user_row;
			end if;
		end;
	begin
		v_time := r.getd('s$user_rctime');
		if v_time is null or (sysdate - v_time) * 24 * 60 > 3 then
			-- if more than n minutes, use new version result cache
			v_time := sysdate;
		end if;
		rcpv.user_hit := true;
		rcpv.user_row := rc2row(p_username, v_time);
	exception
		when not_match then
			rcpv.user_hit := false;
			select a.* into rcpv.user_row from user_t a where a.name = p_username;
			rcpv.user_row := rc2row(p_username, v_time);
			r.setd('s$user_rctime', v_time);
	end;

	procedure set_term_info(p_msid varchar2) is
		function rc2row
		(
			key varchar2,
			ver varchar2
		) return term_t%rowtype result_cache is
		begin
			if rcpv.term_hit then
				raise not_match;
			else
				return rcpv.term_row;
			end if;
		end;
	begin
		rcpv.term_hit := true;
		rcpv.term_ver := r.getc('s$term_ver');
		k_debug.trace(st(p_msid, rcpv.term_ver));
		rcpv.term_row := rc2row(p_msid, rcpv.term_ver);
	exception
		when not_match then
			rcpv.term_hit := false;
			select ora_rowscn into rcpv.term_ver from term_t a where a.msid = p_msid;
			select a.* into rcpv.term_row from term_t a where a.msid = p_msid;
			r.setc('s$term_ver', rcpv.term_ver);
			rcpv.term_row := rc2row(p_msid, rcpv.term_ver);
	end;

end rc;
/
