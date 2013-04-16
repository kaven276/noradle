create or replace package body rc is

	not_match exception;

	procedure set_user_info(p_username varchar2) is
		function rc2row
		(
			key varchar2,
			ver varchar2
		) return user_t%rowtype result_cache is
		begin
			if rcpv.user_ver is not null then
				return rcpv.user_row;
			end if;
			raise not_match;
		end;
	begin
		rcpv.user_ver := null;
		rcpv.user_row := rc2row(p_username, kv.get('user', p_username));
		rcpv.user_hit := true;
	exception
		when not_match then
			rcpv.user_hit := false;
			select a.* into rcpv.user_row from user_t a where a.name = p_username;
			select ora_rowscn into rcpv.user_ver from user_t a where a.name = p_username;
			rcpv.user_row := rc2row(p_username, rcpv.user_ver);
			kv.set('user', p_username, rcpv.user_ver);
	end;

	procedure set_term_info(p_msid varchar2) is
		function rc2row
		(
			key varchar2,
			ver varchar2
		) return term_t%rowtype result_cache is
		begin
			if rcpv.term_ver is not null then
				return rcpv.term_row;
			end if;
			raise not_match;
		end;
	begin
		rcpv.term_ver := null;
		rcpv.term_row := rc2row(p_msid, kv.get('term', p_msid));
		rcpv.term_hit := true;
	exception
		when not_match then
			rcpv.term_hit := false;
			select ora_rowscn into rcpv.term_ver from term_t a where a.msid = p_msid;
			select a.* into rcpv.term_row from term_t a where a.msid = p_msid;
			kv.set('term', p_msid, rcpv.term_ver);
			rcpv.term_row := rc2row(p_msid, rcpv.term_ver);
	end;

end rc;
/
