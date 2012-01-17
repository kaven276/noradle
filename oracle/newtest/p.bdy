create or replace package body p is

	c              utl_tcp.connection;
	gv_cont_len    number;
	gv_header_end  boolean;
	gv_has_content boolean;
	gv_charset     varchar2(30);

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
		gv_header_end  := false;
		gv_has_content := false;
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
		gv_has_content := true;
		gv_charset     := charset;
	end;

	procedure location(url varchar2) is
	begin
		header_line('Location: ' || url);
	end;

	procedure http_header_close is
	begin
		header_line('');
		gv_cont_len   := 0;
		gv_header_end := true;
		if not gv_has_content then
			null; -- go out, cease execution
		end if;
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
		if gv_header_end and not gv_has_content then
			raise_application_error(-20001, 'Content-Type not set in http header, but want to write http body');
		end if;
		if gv_charset = 'UTF-8' then
			if gv_cont_len + lengthb(str) * 1.5 + 2 > gateway.gc_buff_size then
				utl_tcp.flush(c);
				gv_cont_len := 0;
			end if;
			dummy       := utl_tcp.write_line(c, str);
			gv_cont_len := gv_cont_len + lengthb(str) * 1.5 + 2;
		elsif gv_charset = 'GBK' then
			if gv_cont_len + lengthb(str) + 2 > gateway.gc_buff_size then
				utl_tcp.flush(c);
				gv_cont_len := 0;
			end if;
			dummy := utl_tcp.write_line(c, str);
			-- dummy       := utl_tcp.write_raw(c, utl_i18n.string_to_raw(str || chr(13)));
			gv_cont_len := gv_cont_len + lengthb(str) + 2;
		else
			raise_application_error(-20001, 'other than utf/gbk charset is not supported yet');
		end if;
	end;

	procedure flush is
	begin
		utl_tcp.flush(c);
	end;

end p;
/
