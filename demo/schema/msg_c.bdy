create or replace package body msg_c is

	procedure say_something is
	begin
		dbms_pipe.pack_message(r.getc('message'));
		tmp.n := dbms_pipe.send_message('bbs');
		dbms_pipe.pack_message(r.getc('message'));
		tmp.n := dbms_pipe.send_message('bbs');
		h.redirect(r.referer);
	end;

	procedure compute_callback is
	begin
		dbms_pipe.pack_message(r.getn('result'));
		tmp.n := dbms_pipe.send_message(r.getc('h$pipename', 'cb'));
	end;

end msg_c;
/
