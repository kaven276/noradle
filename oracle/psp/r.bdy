create or replace package body r is

	gc_date_fmt constant varchar2(21) := 'yyyy-mm-dd hh24:mi:ss';

	v_url    varchar2(1000);
	v_proto  varchar2(10);
	v_hostn  varchar2(99);
	v_port   positive;
	v_host   varchar2(99);
	v_sdns   varchar2(99);
	v_pdns   varchar2(99);
	v_method varchar2(10);
	v_gid    varchar2(99);
	v_prog   varchar2(61);
	v_pack   varchar2(30);
	v_proc   varchar2(30);
	v_dir    varchar2(250);
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

	procedure get
	(
		name   varchar2,
		value  in out nocopy varchar2 character set any_cs,
		defval varchar2 := null
	) is
	begin
		value := ra.params(name) (1);
	exception
		when no_data_found then
			value := defval;
	end;

	-- Refactored procedure extract_user_pass 
	procedure extract_user_pass is
		v_credential varchar2(100);
		v_parts      st;
	begin
		get('h$authorization', v_credential);
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

	-- Refactored procedure set_get_uamd5 
	procedure set_get_uamd5(v_uamd5 in out varchar2) is
	begin
		if ra.params.exists('h$user-agent') then
			-- at session creation
			k_gac.gset('UA_CTX', v_uamd5, nvl(ra.params('h$user-agent') (1), 'NULL'));
		else
			ra.params('h$user-agent') := st(nvl(sys_context('UA_CTX', v_uamd5), 'LOST'));
		end if;
	end;

	procedure after_map is
	begin
		get('x$dbu', gv_dbu);
		get('x$prog', v_prog);
		get('x$pack', v_pack);
		get('x$proc', v_proc);
		-- get before,after,static
		v_type := substrb(nvl(v_pack, v_proc), -1);
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
	
		ra.params.delete;
		rc.params.delete;
		loop
			v_name  := utl_tcp.get_line(c, true);
			v_value := utl_tcp.get_line(c, true);
			exit when v_name is null;
			if v_value is null then
				v_st := st(null);
			else
				t.split(v_st, v_value, '~', substrb(v_name, 1, 1) != ' ' and substrb(v_name, -1) != ' ');
			end if;
			ra.params(trim(v_name)) := v_st;
		end loop;
	
		-- basic input
		case pv.protocol
			when 'HTTP' then
				get('u$method', v_method);
				get('u$proto', v_proto);
				get('u$hostname', v_hostn);
				v_port := getn('u$port', 80);
				get('u$url', v_url);
				get('u$dir', v_dir);
				get('u$qstr', v_qstr);
			
				get('c$BSID', pv.bsid);
				get('c$MSID', pv.msid);
				get('i$gid', v_gid);
				-- get i$nid
			
				get('a$caddr', gv_caddr);
				gv_cport := getn('a$cport');
				get('a$uamd5', v_uamd5);
			
			when 'DATA' then
				null;
		end case;
	
		rb.charset_http := null;
		rb.charset_db   := null;
		rb.blob_entity  := null;
		rb.clob_entity  := null;
		rb.nclob_entity := null;
	
		dbms_session.clear_identifier;
		if false then
			set_get_uamd5(v_uamd5);
		end if;
	
		-- credentials
		if pv.protocol = 'HTTP' then
			extract_user_pass;
		end if;
	
		-- read post from application/x-www-form-urlencoded or multipart/form-data or other mime types
		if pv.protocol = 'HTTP' and v_method = 'POST' then
			if header('content-type') like 'application/x-www-form-urlencoded%' or
				 header('content-type') like 'multipart/form-data%' then
				null; -- form key-value pairs already got
			else
				declare
					v_len number(10);
					v_pos pls_integer;
				begin
					v_len := to_number(header('content-length'));
					if v_len is null or v_len = 0 then
						return;
					end if;
					getblob(v_len, rb.blob_entity);
					-- maybe for security lobs only
					-- dbms_lob.setcontenttype(rb.blob_entity, gv_headers('content-type'));
					v_pos           := instrb(header('content-type'), '=');
					rb.charset_http := t.tf(v_pos > 0, trim(substr(header('content-type'), v_pos + 1)), 'UTF-8');
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

	function method return varchar2 is
	begin
		return v_method;
	end;

	function protocol return varchar2 is
	begin
		return v_proto;
	end;

	function pdns return varchar2 is
	begin
		return r.getc('u$pdns');
	end;

	function sdns return varchar2 is
	begin
		return r.getc('u$sdns');
	end;

	function hostname return varchar2 is
	begin
		return v_hostn;
	end;

	function port return pls_integer is
	begin
		return v_port;
	end;

	function host return varchar2 is
	begin
		if is_null('h$host') then
			if port = 80 then
				return v_hostn;
			else
				return v_hostn || ':' || to_number(v_port);
			end if;
		else
			return getc('h$host');
		end if;
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

	function site return varchar2 is
	begin
		return v_proto || '://' || host;
	end;

	function pathname return varchar2 is
	begin
		return getc('u$pathname', '');
	end;

	function subpath return varchar2 is
	begin
		return getc('u$spath', '');
	end;

	function dir return varchar2 is
	begin
		return v_dir;
	end;

	function dir_full return varchar2 is
	begin
		return site || v_dir;
	end;

	function qstr return varchar2 is
	begin
		return v_qstr;
	end;

	function url return varchar2 is
	begin
		return v_url;
	end;

	function url_full return varchar2 is
	begin
		return site || url;
	end;

	function type return varchar2 is
	begin
		return v_type;
	end;

	/*
  
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
  
  */

	function error_str(name varchar2) return varchar2 is
	begin
		return 'parameter [' || name || '] not exists and no default provided';
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

	procedure setc
	(
		name  varchar2,
		value varchar2 character set any_cs
	) is
	begin
		if name not like '_$%' then
			ra.params(name) := st(utl_url.escape(value, false, pv.cs_req));
		elsif substrb(name, 1, 1) = 's' then
			ra.params(name) := st(utl_url.escape(value, false, 'AL32UTF8'));
			rc.params(name) := st(utl_url.escape(value, false, 'AL32UTF8'));
		else
			ra.params(name) := st(value);
		end if;
	end;

	procedure setn
	(
		name  varchar2,
		value number
	) is
	begin
		if name like 's$%' then
			rc.params(name) := st(to_char(value));
		end if;
		ra.params(name) := st(to_char(value));
	end;

	procedure setd
	(
		name  varchar2,
		value date
	) is
	begin
		if name like 's$%' then
			rc.params(name) := st(to_char(value, gc_date_fmt));
		end if;
		ra.params(name) := st(to_char(value, gc_date_fmt));
	end;

	function is_lack(name varchar2) return boolean is
		v varchar2(4000);
	begin
		v := ra.params(name) (1);
		return false;
	exception
		when no_data_found then
			return true;
	end;

	function is_null(name varchar2) return boolean is
		v varchar2(4000);
	begin
		v := ra.params(name) (1);
		return v is null;
	exception
		when no_data_found then
			return true;
	end;

	function getc
	(
		name   varchar2,
		defval varchar2 := null,
		idx    pls_integer := 1
	) return varchar2 is
	begin
		if name not like '_$%' then
			return utl_url.unescape(ra.params(name) (idx), pv.cs_req);
		elsif substrb(name, 1, 1) = 's' then
			return utl_url.unescape(ra.params(name) (idx), 'AL32UTF8');
		else
			return ra.params(name)(idx);
		end if;
	exception
		when no_data_found then
			return defval;
	end;

	function getnc
	(
		name   varchar2,
		defval nvarchar2 := null,
		idx    pls_integer := 1
	) return nvarchar2 is
	begin
		if name not like '_$%' then
			return utl_url.unescape(to_nchar(ra.params(name) (idx)), pv.cs_req);
		elsif substrb(name, 1, 1) = 's' then
			return utl_url.unescape(to_nchar(ra.params(name) (idx)), 'AL32UTF8');
		else
			return ra.params(name)(idx);
		end if;
	exception
		when no_data_found then
			return defval;
	end;

	function getn
	(
		name   varchar2,
		defval number := null,
		format varchar2 := null,
		idx    pls_integer := 1
	) return number is
	begin
		if format is null then
			return to_number(ra.params(name) (idx));
		else
			return to_number(ra.params(name) (idx), format);
		end if;
	exception
		when no_data_found then
			return defval;
	end;

	function getd
	(
		name   varchar2,
		defval date := null,
		format varchar2 := null,
		idx    pls_integer := 1
	) return date is
	begin
		if format is null then
			return to_date(utl_url.unescape(ra.params(name) (idx)), gc_date_fmt);
		else
			return to_date(utl_url.unescape(ra.params(name) (idx)), format);
		end if;
	exception
		when no_data_found then
			return defval;
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

	function cnt(name varchar2) return pls_integer is
	begin
		return ra.params(name).count;
	exception
		when no_data_found then
			return null;
	end;

	function get
	(
		name   varchar2,
		defval varchar2 := null
	) return varchar2 is
	begin
		return ra.params(name)(1);
	exception
		when no_data_found then
			return null;
	end;

	procedure set
	(
		name  varchar2,
		value varchar2
	) is
	begin
		ra.params(name) := st(value);
		if name like 's$%' then
			rc.params(name) := st(value);
		end if;
	end;

	procedure del(name varchar2) is
	begin
		ra.params.delete(name);
		if name like 's$%' then
			rc.params(name) := st('');
		end if;
	end;

	procedure del(names st) is
	begin
		for i in 1 .. names.count loop
			del(names(i));
		end loop;
	end;

	function idle return number is
	begin
		return getn('s$IDLE');
	end;

	function lat return date is
	begin
		return sysdate - getn('s$IDLE') / 1000 / 24 / 60 / 60;
	end;

	function unescape(value varchar2) return varchar2 is
	begin
		return utl_url.unescape(value, pv.cs_req);
	end;

	function header(name varchar2) return varchar2 is
	begin
		return ra.params('h$' || lower(name))(1);
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

	function gid return varchar2 is
	begin
		return getc('i$gid');
	end;

	function cookie(name varchar2) return varchar2 is
	begin
		return ra.params('c$' || name)(1);
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

	function server_family return varchar2 is
	begin
		return getc('a$sfami');
	end;

	function server_addr return varchar2 is
	begin
		return getc('a$saddr');
	end;

	function server_port return pls_integer is
	begin
		return getn('a$sport');
	end;

	function call_type return varchar2 is
	begin
		return pv.protocol;
	end;

end r;
/
