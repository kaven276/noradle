create or replace package body e is

	procedure raise
	(
		err_code pls_integer,
		err_msg  varchar2
	) is
	begin
		raise_application_error(err_code, err_msg);
	end;

	procedure chk
	(
		cond     boolean,
		err_code pls_integer,
		err_msg  varchar2
	) is
	begin
		if cond then
			raise_application_error(err_code, err_msg);
		end if;
	end;

	procedure report
	(
		cond boolean,
		msg  varchar2
	) is
	begin
		if not cond then
			return;
		end if;
		h.status_line(403);
		h.print_init(true);
		if pv.protocol = 'HTTP' then
			h.content_type('text/html');
			x.o('<html>');
			x.o('<body>');
			x.p(' <p>', msg);
			x.a(' <a>', 'Back', r.header('referer'));
			x.c('</body>');
			x.c('</html>');
		elsif pv.protocol = 'DATA' then
			h.content_type('text/plain');
			x.t(msg);
		end if;
		g.finish;
	end;

end e;
/
