create or replace package body auth_b is

	procedure basic is
		v_user varchar2(30) := 'psp.web';
		v_pass varchar2(30) := 'best';
	begin
		if (r.user is null or r.user != v_user) and (r.pass is null or r.pass != v_pass) then
			h.www_authenticate_basic('test');
			p.h;
			p.p('Username should be ' || v_user || ' to pass');
			p.p('Password should be ' || v_pass || ' to pass');
			return;
		end if;
		p.h;
		src_b.link_proc;
		p.p('Hello ' || r.user || ', Welcome to access this page.');
		p.p('You have passed the http basic authentication.');
	end;

	procedure digest is
	begin
		h.sts_501_not_implemented;
		p.h;
		src_b.link_proc;
		p.p('PSP.WEB have not implemented http digest authentication by now.');
	end;

	procedure cookie_gac is
		v_sid varchar2(100);
	begin
		if r.is_null('s$IDLE') then
			if r.bsid is null then
				v_sid := t.gen_token;
				h.set_cookie('PHPSESSID', v_sid, path => r.dir);
			else
				v_sid := r.bsid;
			end if;
			r.setc('s$BSID', v_sid);
		end if;
	
		p.h;
		src_b.link_proc;
		p.br;
	
		if auth_s.user_name is not null then
			p.p(t.ps('You are :1, You have already logged ( at :2 ) in.', st(auth_s.user_name, t.dt2s(auth_s.login_time))));
			p.a('Logout', 'logout');
		else
			p.p('You are anonymous.');
		end if;
	
		p.p('Please fill your name and password to log in.');
		p.form_open('f', 'login', method => 'post');
		p.input_text('company', '', 'company: ');
		p.br;
		p.input_text('name', '', 'username: ');
		p.br;
		p.input_text('pass', '', 'password: ');
	
		p.br;
		p.input_text('maxidle', 15, 'max idle(s): ');
		p.br;
		p.input_text('maxlive', 30, 'max live(s): ');
	
		p.br;
		p.input_text('attr1', 'value1', 'attr1: ');
		p.br;
		p.input_text('attr2', 'value2', 'attr2: ');
	
		p.br;
		p.input_text('scheme', 'NORMAL', 'scheme: ');
		p.br;
		p.input_text('rows_per_page', '10', 'rows per page: ');
	
		p.br;
		p.input_reset('', 'reset');
		p.input_submit('', 'login');
		p.form_close;
	end;

	procedure login is
		v user_t%rowtype;
	begin
		h.allow('POST');
		v.name := r.getc('name');
		v.pass := r.getc('pass');
		select count(*)
			into tmp.cnt
			from user_t a
		 where a.name = v.name
			 and a.pass = v.pass;
		e.report(tmp.cnt = 0, 'User name or password is wrong.');
	
		-- record login status in session
		auth_s.login_complex(v.name);
		profile_s.set_scheme(r.getc('scheme'));
		profile_s.set_rows_per_page(r.getn('rows_per_page'));
	
		p.h;
		src_b.link_proc;
		p.p('Welcome ' || auth_s.user_name || ', you have logged in successfully.');
		p.a('relogin', 'cookie_gac');
	end;

	procedure logout is
	begin
		auth_s.logout;
		h.go('cookie_gac');
	end;

	procedure check_maxidle is
	begin
		if r.getn('s$IDLE') > to_number(r.getn('s$maxidle')) * 1000 then
			p.h;
			p.p('You logged in session is timeout for idle more than 15s, session is removed.');
			p.p('last access time : ' || to_char(r.lat, 'hh:mm:ss'));
			p.p('current time : ' || to_char(sysdate, 'hh:mm:ss'));
			p.p('max idle threshold : ' || r.getn('s$maxidle') || ' seconds');
			auth_s.logout;
			g.cancel;
		end if;
	end;

	procedure check_maxlive is
	begin
		if auth_s.login_time + r.getn('s$maxlive') / 24 / 60 / 60 < sysdate then
			p.h;
			p.p('You logged in session lived for too long, that is more than 1 minute, session is removed.');
			p.p('login time : ' || to_char(auth_s.login_time, 'hh:mm:ss'));
			p.p('current time : ' || to_char(sysdate, 'hh:mm:ss'));
			p.p('max live threshold : ' || r.getn('s$maxlive') || ' seconds');
			auth_s.logout;
			g.cancel;
		end if;
	end;

	procedure check_update is
	begin
		check_maxidle;
		check_maxlive;
	end;

	procedure protected_page is
	begin
		p.h;
		if auth_s.user_name is null then
			h.sts_403_forbidden;
			p.p('You have not logged in.');
			p.a('login now', 'cookie_gac');
			return;
		end if;
	
		src_b.link_proc;
		p.br;
		p.p('This page show how to deal with login/logout fair, instead of using k_filter.before.');
		p.p(t.ps('You are :1 at :4, You have are logged in at :2 with method(:3).',
						 st(auth_s.user_name, t.dt2s(auth_s.login_time), r.getc('s$method'), r.getc('s$company'))));
		p.p('some example session attribute include');
		p.p('attr1 = ' || r.getc('s$attr1'));
		p.p('attr2 = ' || r.getc('s$attr2'));
		p.p('session in demo_profile');
		p.p('scheme = ' || profile_s.get_scheme);
		p.p('rows per page = ' || profile_s.get_rows_per_page);
		p.a('relogin', 'cookie_gac');
	
		p.br(4);
		src_b.link_proc('rc.set_user_info');
		rc.set_user_info(auth_s.user_name);
		p.p('using result cache for user_t, we got the rowtype info');
		p.p('result cache ' || t.tf(rcpv.user_hit, 'hit', 'miss'));
		p.p('username=' || rcpv.user_row.name);
		p.p('password=' || rcpv.user_row.pass);
		p.p('crt_time=' || t.dt2s(rcpv.user_row.ctime));
	exception
		when no_data_found /*s.over_max_idle*/
		 then
			h.sts_403_forbidden;
			p.p(t.ps('You are :1, You last access time is ( at :2 ) in.', st(auth_s.user_name, t.dt2s(r.lat))));
			p.p('But this system allow only 60 seconds of idle time, then it will timeout the session.');
			p.a('relogin now', 'cookie_gac');
		when others /*s.over_max_keep*/
		 then
			h.sts_403_forbidden;
			p.p(t.ps('You are :1, You have already logged ( at :2 ) in.', st(auth_s.user_name, t.dt2s(auth_s.login_time))));
			p.p('But this system allow only 10 minute use after successful login.');
			p.a('relogin now', 'cookie_gac');
	end;

	procedure basic_and_cookie is
		v_user varchar2(30) := 'psp.web';
		v_pass varchar2(30) := 'best';
		v      user_t%rowtype;
	begin
		if auth_s.user_name is not null then
			null;
			k_debug.trace('user in login sts');
		elsif r.user is null and r.pass is null then
			k_debug.trace('no user/pass');
			h.www_authenticate_basic('test');
			p.h;
			p.p('You should login first');
			p.script_text('alert("You should login first.");');
			g.cancel;
		elsif r.user = v_user and r.pass = v_pass then
			auth_s.login_simple(r.user);
			k_debug.trace('user psp.web passed');
		else
			v.name := r.user;
			v.pass := r.pass;
			select count(*)
				into tmp.cnt
				from user_t a
			 where a.name = v.name
				 and a.pass = v.pass;
			if tmp.cnt = 0 then
				k_debug.trace('user dbu not passed');
				h.www_authenticate_basic('test');
				p.h;
				p.p('Username should be ' || v_user || ' to pass');
				p.p('Password should be ' || v_pass || ' to pass');
				p.p('Or user/pass should be in user_t table.' || p.a('see data', 'user_b.register'));
				g.cancel;
			else
				k_debug.trace('user dbu passed');
				auth_s.login_simple(r.user);
			end if;
		end if;
	
		-- already logged in
		p.h;
		src_b.link_proc;
		p.br;
		p.a('Logout', 'logout_basic');
		p.p('Hello ' || r.user || ', Welcome to access this page.');
		p.p('You have passed the http basic authentication sometime ago or at right now.');
		p.p('And you use cookie and gac to mark your logged-in status.');
		p.p('So you do not need to check user/password(cause I/O from password table) for every request.');
		p.p('So you saved the so frenquently I/O operation and avoid the tranditional I/O budden of http basic authentication');
		p.p('Normally, you can not logout for http basic authentication.');
		p.p('But sometime you MAY logout with response 401, so the browser will not send last used user/pass to server.');
	end;

	procedure logout_basic is
	begin
		auth_s.logout;
		h.www_authenticate_basic('please click cancel to logout basic authentication.');
		p.h;
		p.a('login', 'basic_and_cookie');
	end;

end auth_b;
/
