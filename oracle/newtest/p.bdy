create or replace package body p is

	c           utl_tcp.connection;
	gv_cont_len number;

	procedure "_init"
	(
		conn     in out nocopy utl_tcp.connection,
		passport pls_integer
	) is
	begin
		if passport != 80526 then
			raise_application_error(-20000, 'can not call psp.web''s internal method');
		end if;
		c           := conn;
		gv_cont_len := 0;
	end;

	-- private
	procedure header_line(str varchar2) is
		dummy pls_integer;
	begin
		dummy := utl_tcp.write_line(c, str);
	end;

	procedure status_line(code pls_integer := 200) is
	begin
		header_line(code);
	end;

	procedure write_header
	(
		name  varchar2,
		value varchar2
	) is
	begin
		header_line(name || ': ' || value);
	end;

	procedure content_type
	(
		mime_type varchar2 := 'text/html',
		charset   varchar2 := 'UTF-8'
	) is
	begin
		header_line('Content-Type: ' || mime_type || '; charset=' || charset);
	end;

	procedure location(url varchar2) is
	begin
		header_line('Location: ' || url);
	end;

	procedure http_header_close is
	begin
		header_line('');
	end;

	procedure go(url varchar2) is
	begin
		status_line(303);
		location(url);
		http_header_close;
	end;

	-- public
	procedure line(str varchar2) is
		dummy pls_integer;
	begin
		gv_cont_len := gv_cont_len + length(str) + 2;
		if gv_cont_len * 2 > gateway.gc_buff_size then
			utl_tcp.flush(c);
			gv_cont_len := 0;
		end if;
		dummy := utl_tcp.write_line(c, str);
	end;

	procedure flush is
	begin
		utl_tcp.flush(c);
	end;

end p;
/
