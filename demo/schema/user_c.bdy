create or replace package body user_c is

	procedure register is
		v user_t%rowtype;
	begin
		v.name  := r.getc('name');
		v.pass  := r.getc('pass');
		v.ctime := sysdate;

		e.report(v.name is null, 'User''s name is empty!');
		e.report(v.pass is null, 'User''s password is empty!');
		select count(*) into tmp.cnt from user_t a where a.name = v.name;
		e.report(tmp.cnt = 1, 'Username ' || v.name || ' is existed already.');
		e.report(not regexp_like(v.name, '^[A-Za-z ]*$'), 'Username must composed of characters and space only.');

		insert into user_t a values v;

		case r.getc('fb')
			when 'N' then
				h.gol('@b.register');
			when 'Y' then
				pc.h;
				src_b.link_proc;
				x.p('<p>', t.ps('User ":1" is created with password set to ":2".', st(v.name, v.pass)));
				x.p('<p>', 'Click ' || x.a('<a>', 'here', 'javascript:history.back();') || ' to go back');
			else
				null; -- PSP.WEB will automatically redirect back if nothing is output and status=200
		end case;
	end;

	procedure remove is
	begin
		h.allow_get;
		delete from user_t a where a.name = r.getc('name');
		h.redirect(r.referer);
	end;

end user_c;
/
