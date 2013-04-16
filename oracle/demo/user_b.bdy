create or replace package body user_b is

	procedure register is
	begin
		h.expires_now;
		p.h;
		src_b.link_proc;
		p.br;
		src_b.link_pack(u('@c'));
		p.br;
		p.hn(3, 'There is the existing user list.');
		p.table_open('all', cellpadding => 4);
		p.thead_open;
		p.tr(p.ths('USERNAME,PASSWORD,CREATE TIME,OPERATION'));
		p.thead_close;
		for i in (select * from user_t a order by a.ctime asc) loop
			p.tr(p.tds(st(i.name, i.pass, t.dt2s(i.ctime), p.a('remove', '@c.remove?name=' || i.name))));
		end loop;
		p.table_close;
		p.br;

		p.form_open('f', '@c.register', method => 'post');
		-- p.form_open('f', 'basic_io_b.req_info', method => 'post');
		p.input_text('name', '', 'username: ');
		p.br;
		p.input_text('pass', '', 'password: ');
		p.br;
		p.split2('Y=Y;N=N;', ';=');
		p.input_radios('fb', '', 'need feedback');
		p.br;
		p.input_reset('', 'reset form');
		p.input_submit('', 'create new user');
		p.form_close;

		p.p('When post form info, _c will check error and report 403 error message page directly, ' ||
				'If all is ok, _c can call h.go to redirect to a page such as go back, ' ||
				'If nothing is output and status=200(default) PSP.WEB will automatically redirect back, ' ||
				'If _c show some feedback info itself, PSP.WEB will redirect to the feedback url to prevent repeating valid post.');
	end;

end user_b;
/
