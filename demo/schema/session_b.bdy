create or replace package body session_b is

	procedure login_form is
		s_user varchar2(30) := r.getc('s$user', '');
		v_sid  varchar2(100);
	begin
		-- create session store with right sid in node
		-- if session store is not been created
		-- cookie name mimic PHP's session cookie name
		if r.is_null('s$IDLE') then
			if r.bsid is null then
				v_sid := t.gen_token;
				h.set_cookie('PHPSESSID', v_sid, path => r.dir);
			else
				v_sid := r.bsid;
			end if;
			r.setc('s$BSID', v_sid);
		end if;
		x.t('<!doctype HTML>');
		x.p('<p>', 'logged user is ' || s_user);
		x.o('<form action=:1,method=post>', st(l('@b.login_check')));
		x.v(' <input type=text,name=user>', s_user);
		x.s(' <input type=submit>');
		x.c('</form>');
	end;

	procedure login_check is
		p_user varchar2(30) := r.getc('user');
	begin
		r.setc('s$user', p_user);
		if p_user is not null then
			h.gol('@b.user_page', 303);
		else
			h.gol('@b.logout_info', 303);
		end if;
	end;

	procedure logout_info is
	begin
		x.t('<!doctype HTML>');
		x.p('<p>', 'You are logged out successfully!');
		x.a('<a>', 'click to login again', '@b.login_form');
	end;

	procedure user_page is
	begin
		x.t('<!doctype HTML>');
		x.p('<p>', 'logged user is ' || r.getc('s$user', 'nobody'));
		x.p('<p>', 'your have been idle for ' || ceil(r.getn('s$IDLE', 0) / 1000) || ' seconds');
		x.p('<p>', 'last access time is ' || r.lat);
		x.a('<a>', 'click to login using different user name', '@b.login_form');
		x.a('<a>', 'logout', '@b.logout');
	end;

	procedure logout is
	begin
		if not r.is_null('s$IDLE') then
			r.setc('s$BSID', '');
		end if;
		h.gol('@b.logout_info', 303);
	end;

end session_b;
/
