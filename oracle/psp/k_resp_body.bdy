create or replace package body k_resp_body is

	procedure flush is
	begin
		pv.accum_cnt := 0;
		output.flush;
	end;

	function flushed return boolean is
	begin
		return pv.flushed;
	end;

	function written return pls_integer is
	begin
		return output.get_buf_byte_len;
	end;

	function inc_buf_cnt return pls_integer is
	begin
		pv.accum_cnt := pv.accum_cnt + 1;
		return pv.accum_cnt;
	end;

	procedure use_bom(value varchar2) is
	begin
		pv.bom := replace(value, ' ', '');
	end;

	procedure download(content in out nocopy blob) is
		v_len pls_integer;
	begin
		v_len := dbms_lob.getlength(content);
		pv.headers('Content-Length') := to_char(v_len);
		output.write_head;
		pv.wlen := utl_tcp.write_raw(pv.c, content);
		k_debug.trace(st('download blob len', dbms_lob.getlength(content), pv.wlen));
	end;

	procedure download(content in out nocopy clob character set any_cs) is
		v_len    pls_integer;
		v_csize  pls_integer := 10000;
		v_offset pls_integer := 0;
		v_buffer varchar2(10000);
	begin
		-- todo: only all single-byte(like ASCII) clob is supported
		if true then
			v_len := dbms_lob.getlength(content);
			pv.headers('Content-Length') := to_char(v_len);
			output.write_head;
			pv.wlen := utl_tcp.write_text(pv.c, content);
		else
			loop
				v_buffer := dbms_lob.substr(content, v_csize, v_offset);
				output.line(v_buffer, '');
				exit when length(v_buffer) < v_csize;
				v_offset := v_offset + v_csize;
			end loop;
		end if;
		k_debug.trace(st('download clob len', dbms_lob.getlength(content), pv.wlen));
	end;

	procedure print_init(force boolean := false) is
	begin
		if force or pv.pg_len is null then
			output."_init"(80526);
		end if;
	end;

	-- public
	procedure write_raw(data in out nocopy raw) is
		v_len pls_integer;
	begin
		v_len := utl_raw.length(data);
		if data is null or v_len = 0 then
			return;
		end if;
	
		if pv.use_stream then
			pv.wlen := utl_tcp.write_raw(pv.c, data);
		else
			output.line(utl_raw.cast_to_nvarchar2(data), '');
		end if;
	end;

	procedure write(text varchar2 character set any_cs) is
	begin
		output.line(text, '');
	end;

	procedure writeln(text varchar2 character set any_cs := '') is
	begin
		output.line(text, pv.nlbr);
	end;

	procedure string(text varchar2 character set any_cs) is
	begin
		output.line(text, '');
	end;

	procedure line(text varchar2 character set any_cs := '') is
	begin
		output.line(text, pv.nlbr);
	end;

	procedure w(text varchar2 character set any_cs) is
	begin
		output.line(text, '');
	end;

	procedure l(text varchar2 character set any_cs := '') is
	begin
		output.line(text, pv.nlbr);
	end;

	procedure iline
	(
		str    varchar2 character set any_cs,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	) is
	begin
		output.line(str, nl, indent);
	end;

	procedure set_line_break(nlbr varchar2) is
	begin
		pv.nlbr := nlbr;
	end;

	procedure save_pointer is
	begin
		if pv.pg_nchar then
			pv.pg_svptr := pv.pg_len + nvl(lengthb(pv.pg_buf), 0);
		else
			pv.pg_svptr := pv.pg_len + nvl(lengthb(pv.ph_buf), 0);
		end if;
	end;

	function appended return boolean is
	begin
		if pv.pg_nchar then
			return pv.pg_svptr != pv.pg_len + nvl(lengthb(pv.pg_buf), 0);
		else
			return pv.pg_svptr != pv.pg_len + nvl(lengthb(pv.ph_buf), 0);
		end if;
	end;

	function not_appended return boolean is
	begin
		return not appended;
	end;

	procedure begin_template(nl varchar2 := '') is
	begin
		output.switch;
		if pv.pg_nchar then
			pv.pg_buf := '';
		else
			pv.ph_buf := '';
		end if;
		pv.nlbr0 := pv.nlbr;
		pv.nlbr  := nl;
	end;

	procedure end_template(tpl in out nocopy varchar2 character set any_cs) is
	begin
		if pv.pg_nchar then
			tpl       := pv.pg_buf;
			pv.pg_buf := '';
		else
			tpl       := pv.ph_buf;
			pv.ph_buf := '';
		end if;
		pv.nlbr := pv.nlbr0;
	end;

end k_resp_body;
/
