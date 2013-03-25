create or replace package body r is

	gc_date_fmt constant varchar2(21) := 'yyyy-mm-dd hh24:mi:ss';

	v_url    varchar2(1000);
	v_proto  varchar2(10);
	v_host   varchar2(99);
	v_hostp  varchar2(30);
	v_port   positive;
	v_method varchar2(10);
	v_base   varchar2(99);
	v_dad    varchar2(30);
	v_prog   varchar2(61);
	v_pack   varchar2(30);
	v_proc   varchar2(30);
	v_path   varchar2(500);
	v_qstr   varchar2(4000);
	v_type   char(1);
	v_user   varchar2(30);
	v_pass   varchar2(30);

	gv_dbu  varchar2(30);
	gv_file varchar2(1000);

	gv_caddr varchar2(30);
	gv_cport positive;

	procedure getblob
	(
		p_len  in pls_integer,
		p_blob in out nocopy blob
	) is
		v_raw  raw(32767);
		v_size pls_integer;
		v_read pls_integer := 0;
		v_rest pls_integer := p_len;
	begin
		dbms_lob.createtemporary(p_blob, cache => true, dur => dbms_lob.call);
		loop
			v_size := utl_tcp.read_raw(pv.c, v_raw, least(32767, v_rest));
			v_rest := v_rest - v_size;
			dbms_lob.writeappend(p_blob, v_size, v_raw);
			exit when v_rest = 0;
		end loop;
	end;

	procedure "_init"
	(
		c        in out nocopy utl_tcp.connection,
		passport pls_integer
	) is
		v_name  varchar2(1000);
		v_value varchar2(32000);
		v_st    st;
		v_uamd5 varchar2(22);
	begin
		if passport != 80526 then
			raise_application_error(-20000, 'can not call psp.web''s internal method');
		end if;
	
		-- basic input
		case pv.protocol
			when 'HTTP' then
				v_method := utl_tcp.get_line(c, true);
				v_url    := utl_tcp.get_line(c, true);
				v_proto  := utl_tcp.get_line(c, true);
				v_host   := utl_tcp.get_line(c, true);
				v_hostp  := utl_tcp.get_line(c, true);
				v_port   := to_number(utl_tcp.get_line(c, true));
				v_base   := utl_tcp.get_line(c, true);
				v_dad    := utl_tcp.get_line(c, true);
				v_prog   := utl_tcp.get_line(c, true);
				v_pack   := utl_tcp.get_line(c, true);
				v_proc   := utl_tcp.get_line(c, true);
				v_path   := utl_tcp.get_line(c, true);
				v_qstr   := utl_tcp.get_line(c, true);
				v_type   := substrb(nvl(v_pack, v_proc), -1);
				gv_caddr := utl_tcp.get_line(c, true);
				gv_cport := to_number(utl_tcp.get_line(c, true));
				pv.bsid  := utl_tcp.get_line(c, true);
				pv.msid  := utl_tcp.get_line(c, true);
				v_uamd5  := utl_tcp.get_line(c, true);
			
				if v_dad is null then
					v_dad := lower(k_cfg.server_control().default_dbu);
				end if;
			
				if regexp_like(v_dad, lower(k_cfg.server_control().dbu_filter)) then
					gv_dbu := v_dad;
				else
					gv_dbu := lower(k_cfg.server_control().default_dbu);
				end if;
			
			when 'DATA' then
				gv_dbu := lower(utl_tcp.get_line(c, true));
				v_prog := utl_tcp.get_line(c, true);
				v_proc := utl_tcp.get_line(c, true);
				v_pack := utl_tcp.get_line(c, true);
		end case;
	
		pv.schema := dbu;
		pv.prog   := v_prog;
	
		ra.headers.delete;
		ra.cookies.delete;
		ra.params.delete;
	
		rb.charset_http := null;
		rb.charset_db   := null;
		rb.blob_entity  := null;
		rb.clob_entity  := null;
		rb.nclob_entity := null;
		-- read headers
		loop
			v_name := utl_tcp.get_line(c, true);
			exit when v_name is null;
			v_value := utl_tcp.get_line(c, true);
			ra.headers(v_name) := v_value;
		end loop;
	
		dbms_session.clear_identifier;
		if false then
			if ra.headers.exists('user-agent') then
				-- at session creation
				k_gac.gset('UA_CTX', v_uamd5, nvl(ra.headers('user-agent'), 'NULL'));
			else
				ra.headers('user-agent') := nvl(sys_context('UA_CTX', v_uamd5), 'LOST');
			end if;
		end if;
	
		-- credentials
		if pv.protocol = 'HTTP' then
			declare
				v_credential varchar2(100);
				v_parts      st;
			begin
				v_credential := ra.headers('authorization');
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
			end;
		end if;
	
		-- read cookies
		if pv.protocol = 'HTTP' then
			loop
				v_name := utl_tcp.get_line(c, true);
				exit when v_name is null;
				v_value := utl_tcp.get_line(c, true);
				ra.cookies(v_name) := v_value;
			end loop;
		end if;
	
		-- read query string
		loop
			v_name := utl_tcp.get_line(c, true);
			exit when v_name is null;
			v_value := utl_tcp.get_line(c, true);
			if v_value is null then
				v_st := st(null);
			else
				t.split(v_st, v_value, ',', substrb(v_name, 1, 1) != ' ' and substrb(v_name, -1) != ' ');
			end if;
			ra.params(trim(v_name)) := v_st;
		end loop;
	
		-- read post from application/x-www-form-urlencoded or multipart/form-data or other mime types
		if pv.protocol = 'HTTP' and v_method = 'POST' then
			if ra.headers('content-type') like 'application/x-www-form-urlencoded%' or
				 ra.headers('content-type') like 'multipart/form-data%' then
				loop
					v_name := utl_tcp.get_line(c, true);
					exit when v_name is null;
					v_value := utl_tcp.get_line(c, true);
					if v_value is null then
						v_st := st(null);
					else
						t.split(v_st, v_value, ',', substrb(v_name, 1, 1) != ' ' and substrb(v_name, -1) != ' ');
					end if;
					ra.params(trim(v_name)) := v_st;
				end loop;
			else
				declare
					v_len number(10);
					v_pos pls_integer;
				begin
					v_len := to_number(ra.headers('content-length'));
					if v_len is null or v_len = 0 then
						return;
					end if;
					getblob(v_len, rb.blob_entity);
					-- maybe for security lobs only
					-- dbms_lob.setcontenttype(rb.blob_entity, gv_headers('content-type'));
					v_pos           := instrb(ra.headers('content-type'), '=');
					rb.charset_http := t.tf(v_pos > 0, trim(substr(ra.headers('content-type'), v_pos + 1)), 'UTF-8');
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
		v_lc   integer := 0;
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

	procedure read_line_init(nl varchar2 := null) is
	begin
		pv.rl_pos := 1;
		pv.rl_end := false;
		pv.rl_nlc := nvl(nl, chr(13) || chr(10));
	end;

	procedure read_line(line in out nocopy varchar2) is
		v_end number(10);
		v_amt number(5);
	begin
		e.chk(pv.rl_end, -20016, 'read line is over, can not use r.read_line for more');
		v_end := dbms_lob.instr(rb.clob_entity, pv.rl_nlc, pv.rl_pos);
		if v_end = 0 then
			pv.rl_end := true;
			v_end     := dbms_lob.getlength(rb.clob_entity) + 1;
		elsif v_end is null then
			e.chk(rb.clob_entity is null, -20015, 'rb.clob_entity is null, can not use r.read_line');
		end if;
		v_amt := v_end - pv.rl_pos;
		dbms_lob.read(rb.clob_entity, v_amt, pv.rl_pos, line);
		pv.rl_pos := v_end + length(pv.rl_nlc);
	end;

	procedure read_nline(line in out nocopy nvarchar2) is
		v_end number(10);
		v_amt number(5);
	begin
		e.chk(pv.rl_end, -20016, 'read line is over, can not use r.read_line for more');
		v_end := dbms_lob.instr(rb.nclob_entity, pv.rl_nlc, pv.rl_pos);
		if v_end = 0 then
			pv.rl_end := true;
			v_end     := dbms_lob.getlength(rb.nclob_entity) + 1;
		elsif v_end is null then
			e.chk(rb.nclob_entity is null, -20015, 'rb.nclob_entity is null, can not use r.read_line');
		end if;
		v_amt := v_end - pv.rl_pos;
		dbms_lob.read(rb.nclob_entity, v_amt, pv.rl_pos, line);
		pv.rl_pos := v_end + length(pv.rl_nlc);
	end;

	function read_line_no_more return boolean is
	begin
		return pv.rl_end;
	end;

	function protocol return varchar2 is
	begin
		return v_proto;
	end;

	function host return varchar2 is
	begin
		return v_host;
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
		ra.params(name) := st(value);
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

	procedure req_charset(cs varchar2) is
	begin
		pv.cs_req := utl_i18n.map_charset(cs, 0, 1);
	end;

	procedure req_charset_db is
	begin
		pv.cs_req := pv.cs_char;
	end;

	procedure req_charset_ndb is
	begin
		pv.cs_req := pv.cs_nchar;
	end;

	procedure req_charset_utf8 is
	begin
		pv.cs_req := 'AL32UTF8';
	end;

	procedure getc
	(
		name   varchar2,
		value  in out nocopy varchar2 character set any_cs,
		defval varchar2
	) is
	begin
		value := utl_url.unescape(to_nchar(ra.params(name) (1)), pv.cs_req);
	exception
		when no_data_found then
			value := defval;
	end;

	procedure getc
	(
		name  varchar2,
		value in out nocopy varchar2 character set any_cs
	) is
	begin
		value := utl_url.unescape(to_nchar(ra.params(name) (1)), pv.cs_req);
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
			value := to_number(ra.params(name) (1), format);
		else
			value := to_number(ra.params(name) (1));
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
			value := to_number(ra.params(name) (1), format);
		else
			value := to_number(ra.params(name) (1));
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
		value := to_date(ra.params(name) (1), nvl(format, gc_date_fmt));
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
		value := to_date(ra.params(name) (1), nvl(format, gc_date_fmt));
	exception
		when no_data_found then
			raise_application_error(-20000, error_str(name));
	end;

	function getc
	(
		name   varchar2,
		defval nvarchar2
	) return nvarchar2 is
	begin
		return utl_url.unescape(to_nchar(ra.params(name) (1)), pv.cs_req);
	exception
		when no_data_found then
			return defval;
	end;

	function getc(name varchar2) return nvarchar2 is
	begin
		return utl_url.unescape(to_nchar(ra.params(name) (1)), pv.cs_req);
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
		value := ra.params(name);
	exception
		when no_data_found then
			value := st();
	end;

	function gets(name varchar2) return st is
	begin
		return ra.params(name);
	exception
		when no_data_found then
			return st();
	end;

	procedure unescape_parameters is
	begin
		null;
	end;

	function header(name varchar2) return varchar2 is
	begin
		return ra.headers(lower(name));
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
		return ra.cookies(name);
	exception
		when no_data_found then
			return null;
	end;

	function msid return varchar2 is
	begin
		return pv.msid;
	end;

	function bsid return varchar2 is
	begin
		return pv.bsid;
	end;

	function dbu return varchar2 is
	begin
		return gv_dbu;
	end;

	function file return varchar2 is
	begin
		return gv_file;
	end;

	function url return varchar2 is
	begin
		return v_url;
	end;

	function url_full return varchar2 is
	begin
		if instr(v_url, '://') <= 0 then
			return v_proto || '://' || header('host') || v_url;
		else
			return v_url;
		end if;
	end;

	function dad_path return varchar2 is
	begin
		return t.nvl2(v_base, '/' || v_base) || '/' || v_dad;
	end;

	function dad_path_full return varchar2 is
	begin
		return v_proto || '://' || v_host || t.tf(v_port != 80, ':' || v_port) || dad_path;
	end;

	-- for internal url catacation
	function gu_full_base return varchar2 is
	begin
		return dad_path_full || '/';
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

	function referer return varchar2 is
	begin
		return header('referer');
	end;

	function referer2 return varchar2 is
	begin
		return getc('$referer', header('referer'));
	end;

	function ua return varchar2 is
	begin
		return nullif(header('user-agent'), 'NULL');
	end;

	function client_addr return varchar2 is
	begin
		return gv_caddr;
	end;

	function client_port return pls_integer is
	begin
		return gv_cport;
	end;

	function call_type return varchar2 is
	begin
		return pv.protocol;
	end;

end r;
/
