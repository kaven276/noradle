create or replace package body session_b is

	procedure login_form is
		s_user varchar2(30) := r.session('user');
	begin
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
		r.session('user', p_user);
		if p_user is not null then
			h.redirect(l('@b.user_page'), 303);
		else
			h.redirect(l('@b.logout_info'), 303);
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
		x.p('<p>', 'logged user is ' || r.session('user'));
		x.a('<a>', 'click to login using different user name', '@b.login_form');
	end;

end session_b;
/
