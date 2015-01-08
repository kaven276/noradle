create or replace package body user_b is

	procedure register is
	begin
		h.expires_now;
		pc.h;
		src_b.link_proc;
		x.t('<br/>');
		src_b.link_pack(l('@c'));
		src_b.link_proc(l('@c.register'));
		x.t('<br/>');
		x.p('<h3>', 'There is the existing user list.');
		x.o('<table rules=all,cellpadding=4>');
		x.p(' <thead>', x.p('<tr>', m.w('<th>@</th>', 'USERNAME,PASSWORD,CREATE TIME,OPERATION')));
		x.o(' <tbody>');
		for i in (select * from user_t a order by a.ctime asc) loop
			tmp.stv := st(i.name, i.pass, t.dt2s(i.ctime), x.a('<a>', 'remove', '@c.remove?name=' || i.name));
			x.p('<tr>', m.w('<td>', tmp.stv, '</td>'));
		end loop;
		x.c(' </tbody>');
		x.c('</table>');
		x.t('<br/>');
	
		x.o('<form name=f,action=user_c.register,method=post>');
		-- x.o('<form name=f,action=basic_io_b.req_info,method=post>');
	
		x.p(' <label>', 'username: ');
		x.s(' <input type=text,name=name>');
		x.t(' <br/>');
	
		x.p(' <label>', 'password: ');
		x.s(' <input type=text,name=pass>');
		x.t(' <br/>');
	
		tmp.stv := st('Y', 'N');
		x.p(' <label>', 'need feedback: ');
		m.w(' <input type="radio" name="fb" ?checked value="@"/><label>@</label>', tmp.stv, tmp.stv, 'Y');
		x.t(' <br/>');
	
		x.s(' <input type=reset,value=reset form>');
		x.s(' <input type=submit,value=create new user>');
	
		x.c('</form>');
	
		x.p('<p>',
				'When post form info, _c will check error and report 403 error message page directly, ' ||
				'If all is ok, _c can call h.go to redirect to a page such as go back, ' ||
				'If nothing is output and status=200(default) PSP.WEB will automatically redirect back, ' ||
				'If _c show some feedback info itself, PSP.WEB will redirect to the feedback url to prevent repeating valid post.');
	end;

	procedure data_src is
		cur sys_refcursor;
	begin
		h.content_type('text/resultsets');
		open cur for
			select * from user_t where rownum <= 3;
		rs.print('users', cur);
	end;

end user_b;
/
