create or replace package body r is

	gc_date_fmt constant varchar2(21) := 'yyyy-mm-dd hh24:mi:ss';

	type str_arr is table of varchar2(1000) index by varchar2(100);
	gv_headers str_arr;
	gv_cookies str_arr;

	type st_arr is table of st index by varchar2(100);
	gv_params st_arr;

	v_hostp  varchar2(30);
	v_port   pls_integer;
	v_method varchar2(10);
	v_base   varchar2(100);
	v_dad    varchar2(30);
	v_prog   varchar2(61);
	v_pack   varchar2(30);
	v_proc   varchar2(30);
	v_path   varchar2(500);
	v_qstr   varchar2(256);
	v_hash   varchar2(100);
	v_type   char(1);
	v_user   varchar2(30);
	v_pass   varchar2(30);

	gv_dbu  varchar2(30);
	gv_file varchar2(1000);

	procedure "_init"
	(
		c        in out nocopy utl_tcp.connection,
		passport pls_integer
	) is
		v_name  varchar2(1000);
		v_value varchar2(1000);
		v_st    st;
	begin
		if passport != 80526 then
			raise_application_error(-20000, 'can not call psp.web''s internal method');
		end if;
	
		-- basic input
		v_method := utl_tcp.get_line(c, true);
		v_hostp  := utl_tcp.get_line(c, true);
		v_port   := to_number(utl_tcp.get_line(c, true));
		v_base   := utl_tcp.get_line(c, true);
		v_dad    := utl_tcp.get_line(c, true);
		v_prog   := utl_tcp.get_line(c, true);
		v_pack   := utl_tcp.get_line(c, true);
		v_proc   := utl_tcp.get_line(c, true);
		v_path   := utl_tcp.get_line(c, true);
		v_qstr   := utl_tcp.get_line(c, true);
		v_hash   := utl_tcp.get_line(c, true);
		v_type   := substrb(nvl(v_pack, v_proc), -1);
	
		gv_headers.delete;
		gv_cookies.delete;
		gv_params.delete;
	
		-- read headers
		loop
			v_name  := utl_tcp.get_line(c, true);
			v_value := utl_tcp.get_line(c, true);
			exit when v_name is null and v_value is null;
			gv_headers(v_name) := v_value;
		end loop;
	
		-- credentials
		declare
			v_credential varchar2(100);
			v_parts      st;
		begin
			v_credential := gv_headers('authorization');
			if v_credential is null then
				v_user := null;
				v_pass := null;
			else
				t.split(v_parts, v_credential, ' ');
				case v_parts(1)
					when 'Basic' then
						t.split(v_parts, utl_encode.text_decode(v_parts(2), encoding => utl_encode.base64), ':');
						v_user := v_parts(1);
						v_pass := v_parts(2);
					when 'Digest' then
						null;
				end case;
			end if;
		exception
			when no_data_found then
				v_user := null;
				v_pass := null;
				gv_headers('authorization') := 'null';
		end;
	
		-- read cookies
		loop
			v_name  := utl_tcp.get_line(c, true);
			v_value := utl_tcp.get_line(c, true);
			exit when v_name is null and v_value is null;
			gv_cookies(v_name) := v_value;
		end loop;
	
		-- read query string  
		loop
			v_name  := utl_tcp.get_line(c, true);
			v_value := utl_tcp.get_line(c, true);
			exit when v_name is null and v_value is null;
			t.split(v_st, v_value, ',');
			gv_params(v_name) := v_st;
		end loop;
	
		-- read post from application/x-www-form-urlencoded or multipart/form-data or other mime types
		if v_method = 'POST' then
			if gv_headers('content-type') like 'application/x-www-form-urlencoded%' or
				 gv_headers('content-type') like 'multipart/form-data%' then
				loop
					v_name  := utl_tcp.get_line(c, true);
					v_value := utl_tcp.get_line(c, true);
					exit when v_name is null and v_value is null;
					t.split(v_st, v_value, ',');
					gv_params(v_name) := v_st;
				end loop;
			else
				declare
					v_len   number(10);
					v_read  number(10) := 0;
					v_raw   raw(32767);
					v_chunk number(8);
					v_pos   pls_integer;
				begin
					v_len := to_number(gv_headers('content-length'));
					if v_len is null or v_len = 0 then
						return;
					end if;
					dbms_lob.createtemporary(rb.blob_entity, cache => true, dur => dbms_lob.session);
					loop
						v_chunk := utl_tcp.read_raw(c, v_raw, 32767);
						v_read  := v_read + v_chunk;
						dbms_lob.writeappend(rb.blob_entity, v_chunk, v_raw);
						exit when v_read = v_len;
					end loop;
					-- maybe for security lobs only
					-- dbms_lob.setcontenttype(rb.blob_entity, gv_headers('content-type'));
					v_pos           := instrb(gv_headers('content-type'), '=');
					rb.charset_http := t.tf(v_pos > 0, trim(substr(gv_headers('content-type'), v_pos + 1)), 'UTF-8');
					rb.charset_db   := utl_i18n.map_charset(rb.charset_http, utl_i18n.generic_context, utl_i18n.iana_to_oracle);
				end;
			end if;
		end if;
	
	end;

	procedure body2clob is
		v_len  number(8);
		v_dos  integer := 1;
		v_sos  integer := 1;
		v_csid integer;
		v_lc   integer := 0;
		v_warn integer;
	begin
		v_len  := dbms_lob.getlength(rb.blob_entity);
		v_csid := nvl(nls_charset_id(rb.charset_db), 0);
		dbms_lob.createtemporary(rb.clob_entity, true, dbms_lob.session);
		dbms_lob.converttoclob(rb.clob_entity, rb.blob_entity, v_len, v_dos, v_sos, v_csid, v_lc, v_warn);
	end;

	procedure body2nclob is
		v_len  number(8);
		v_dos  integer := 1;
		v_sos  integer := 1;
		v_csid integer;
		v_lc   integer;
		v_warn integer;
	begin
		v_len  := dbms_lob.getlength(rb.blob_entity);
		v_csid := nvl(nls_charset_id(rb.charset_db), 0);
		dbms_lob.createtemporary(rb.nclob_entity, true, dbms_lob.session);
		dbms_lob.converttoclob(rb.nclob_entity, rb.blob_entity, v_len, v_dos, v_sos, v_csid, v_lc, v_warn);
	end;

	procedure body2auto is
	begin
		if nls_charset_id(rb.charset_db) = nls_charset_id('CHAR_CS') then
			body2clob;
		elsif nls_charset_id(rb.charset_db) = nls_charset_id('NCHAR_CS') then
			body2nclob;
		else
			null;
		end if;
	end;

	function host_prefix return varchar2 is
	begin
		return v_hostp;
	end;

	function port return pls_integer is
	begin
		return v_port;
	end;

	function method return varchar2 is
	begin
		return v_method;
	end;

	function base return varchar2 is
	begin
		return v_base;
	end;

	function dad return varchar2 is
	begin
		return v_dad;
	end;

	function prog return varchar2 is
	begin
		return v_prog;
	end;

	function pack return varchar2 is
	begin
		return v_pack;
	end;

	function proc return varchar2 is
	begin
		return v_proc;
	end;

	function path return varchar2 is
	begin
		return v_path;
	end;

	function qstr return varchar2 is
	begin
		return v_qstr;
	end;

	function hash return varchar2 is
	begin
		return v_hash;
	end;

	function type return varchar2 is
	begin
		return v_type;
	end;

	function error_str(name varchar2) return varchar2 is
	begin
		return 'parameter [' || name || '] not exists and no default provided';
	end;

	procedure setc
	(
		name  varchar2,
		value varchar2
	) is
	begin
		gv_params(name) := st(value);
	end;

	function nc return varchar2 is
	begin
		return null;
	end;

	function nn return number is
	begin
		return null;
	end;

	function nd return date is
	begin
		return null;
	end;

	procedure getc
	(
		name   varchar2,
		value  in out nocopy varchar2,
		defval varchar2
	) is
	begin
		value := gv_params(name) (1);
	exception
		when no_data_found then
			value := defval;
	end;

	procedure getc
	(
		name  varchar2,
		value in out nocopy varchar2
	) is
	begin
		value := gv_params(name) (1);
	exception
		when no_data_found then
			raise_application_error(-20000, error_str(name));
	end;

	procedure getn
	(
		name   varchar2,
		value  in out nocopy number,
		defval number,
		format varchar2 := null
	) is
	begin
		if format is not null then
			value := to_number(gv_params(name) (1), format);
		else
			value := to_number(gv_params(name) (1));
		end if;
	exception
		when no_data_found then
			value := defval;
	end;

	procedure getn
	(
		name   varchar2,
		value  in out nocopy number,
		format varchar2 := null
	) is
	begin
		if format is not null then
			value := to_number(gv_params(name) (1), format);
		else
			value := to_number(gv_params(name) (1));
		end if;
	exception
		when no_data_found then
			raise_application_error(-20000, error_str(name));
	end;

	procedure getd
	(
		name   varchar2,
		value  in out nocopy date,
		defval date,
		format varchar2 := null
	) is
	begin
		value := to_date(gv_params(name) (1), nvl(format, gc_date_fmt));
	exception
		when no_data_found then
			value := defval;
	end;

	procedure getd
	(
		name   varchar2,
		value  in out nocopy date,
		format varchar2 := null
	) is
	begin
		value := to_date(gv_params(name) (1), nvl(format, gc_date_fmt));
	exception
		when no_data_found then
			raise_application_error(-20000, error_str(name));
	end;

	function getc
	(
		name   varchar2,
		defval varchar2
	) return varchar2 is
	begin
		return gv_params(name)(1);
	exception
		when no_data_found then
			return defval;
	end;

	function getc(name varchar2) return varchar2 is
	begin
		return gv_params(name)(1);
	exception
		when no_data_found then
			raise_application_error(-20000, error_str(name));
	end;

	function getn
	(
		name   varchar2,
		defval number,
		format varchar2
	) return number is
		v number;
	begin
		getn(name, v, defval, format);
		return v;
	end;

	function getn
	(
		name   varchar2,
		format varchar2
	) return number is
		v number;
	begin
		getn(name, v, format);
		return v;
	end;

	function getd
	(
		name   varchar2,
		defval date,
		format varchar2
	) return date is
		v date;
	begin
		getd(name, v, defval, format);
		return v;
	end;

	function getd
	(
		name   varchar2,
		format varchar2
	) return date is
		v date;
	begin
		getd(name, v, format);
		return v;
	end;

	procedure gets
	(
		name  varchar2,
		value in out nocopy st
	) is
	begin
		value := gv_params(name);
	end;

	function gets(name varchar2) return st is
	begin
		return gv_params(name);
	exception
		when no_data_found then
			return st();
	end;

	procedure unescape_parameters is
	begin
		null;
	end;

	procedure cgi
	(
		name  varchar2,
		value varchar2
	) is
	begin
		gv_headers(name) := value;
	end;

	function cgi(name varchar2) return varchar2 is
	begin
		return gv_headers(name);
	exception
		when no_data_found then
			return null;
	end;

	function header(name varchar2) return varchar2 is
	begin
		return gv_headers(name);
	exception
		when no_data_found then
			return null;
	end;

	function user return varchar2 is
	begin
		return v_user;
	end;

	function pass return varchar2 is
	begin
		return v_pass;
	end;

	function cookie(name varchar2) return varchar2 is
	begin
		return gv_cookies(name);
	exception
		when no_data_found then
			return null;
	end;

	function gc_msid return varchar2 is
	begin
		return cookie('msid');
	end;

	function gc_lsid return varchar2 is
	begin
		return cookie('lsid');
	end;

	function gc_bsid return varchar2 is
	begin
		return cookie('bsid');
	end;

	function dbu return varchar2 is
	begin
		return nvl(gv_dbu, v_dad);
	end;

	function file return varchar2 is
	begin
		return gv_file;
	end;

	function url return varchar2 is
	begin
		return v_prog || t.nnpre('?', v_qstr);
	end;

	function gu_dad_path return varchar2 is
	begin
		return 'http://' || header('http_host') || '/' || v_base || '/' || v_dad;
	end;

	-- for internal url catacation
	function gu_full_base return varchar2 is
	begin
		return gu_dad_path || '/';
	end;

	function from_prog return varchar2 is
		v  varchar2(1000);
		v1 pls_integer;
		v2 pls_integer;
	begin
		v  := header('http_referer');
		v1 := instr(v, '?');
		if v1 > 0 then
			v := substr(v, 1, v1 - 1);
		end if;
		v2 := instr(v, '/', -1);
		return substr(v, v2 + 1);
	end;

	function etag return varchar2 is
		v varchar2(100) := header('if-none-match');
	begin
		return substrb(v, 2, lengthb(v) - 2);
	end;

	function lmt return date is
	begin
		return t.s2hdt(header('if-modified-since'));
	end;

end r;
/
