create or replace package body p is

	c           utl_tcp.connection;
	gv_cont_len number;

	procedure "_init"(c in out nocopy utl_tcp.connection, passport pls_integer) is
	begin
		if passport != 80526 then
			raise_application_error(-20000, 'can not call psp.web''s internal method');
		end if;
		p.c := c;
	end;

	procedure prepare(mime_type varchar2 := 'text/html', charset varchar2 := 'UTF-8') is
	begin
		gv_cont_len := 0;
		line('200');
		line(mime_type);
		line(charset);
		line('');
		utl_tcp.flush(c);
	end;

	-- public
	procedure line(str varchar2) is
		r pls_integer;
	begin
		gv_cont_len := gv_cont_len + length(str) + 2;
		if gv_cont_len * 2 > gateway.gc_buff_size then
			utl_tcp.flush(c);
			gv_cont_len := 0;
		end if;
		r := utl_tcp.write_line(c, str);
	end;

end p;
/

