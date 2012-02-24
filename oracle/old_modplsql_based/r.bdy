create or replace package body r is

	gc_date_fmt constant varchar2(21) := 'yyyy-mm-dd hh24:mi:ss';

	type st_arr is table of st index by varchar2(100);
	gv_params st_arr;

	type str_arr is table of varchar2(1000) index by varchar2(100);
	gv_cgi_envs str_arr;
	gv_cookies  str_arr;

	gv_compact varchar2(10);
	gv_dbu     varchar2(30);
	gv_dad     varchar2(100);
	gv_prog    varchar2(65);
	gv_pack    varchar2(32);
	gv_proc    varchar2(32);
	gv_file    varchar2(1000);
	gv_prefix  varchar2(30);

	function path_compact_level return varchar2 is
	begin
		return gv_compact;
	end;

	procedure init(na owa.vc_arr, va owa.vc_arr) is
		n      varchar2(100);
		v      varchar2(32000);
		v_path varchar2(100) := cgi('PATH_INFO');
		v_pos  pls_integer;
	begin
		-- url parse
		if lengthb(v_path) = 4 then
			-- root
			gv_compact := 'root';
			gv_dad     := 'psp';
			gv_prog    := 'default_b.d';
		else
			v_pos := instrb(v_path, '/', 5);
			if v_pos <= 0 then
				-- dad only
				gv_compact := 'dad';
				gv_dad     := substrb(v_path, 5);
				gv_prog    := 'default_b.d';
				if gv_dad = 'favicon.ico' then
					gv_dad  := 'psp';
					gv_prog := 'favicon.ico';
				end if;
			else
				-- full path
				gv_compact := null;
				gv_dad     := substrb(v_path, 5, v_pos - 5);
				gv_prog    := substrb(v_path, v_pos + 1);
				if gv_prog is null then
					gv_prog := 'default_b.d';
				end if;
			end if;
		end if;
	
		if gv_prog in ('css', 'feedback') then
			gv_file := null;
			gv_pack := null;
			gv_proc := null;
		elsif regexp_like(gv_prog, '^\w+_(b|c|h)(\.[^/.]+)?$') then
			gv_file := null;
			v_pos   := instrb(gv_prog, '.');
			if v_pos > 0 then
				gv_pack := substrb(gv_prog, 1, v_pos - 1);
				gv_proc := substrb(gv_prog, v_pos + 1);
				if gv_proc in ('js', 'css') then
					gv_pack := null;
					gv_proc := null;
					gv_file := gv_prog;
					gv_prog := null;
				end if;
			else
				gv_pack := null;
				gv_proc := gv_prog;
			end if;
		else
			gv_file := gv_prog;
			gv_prog := null;
			gv_pack := null;
			gv_proc := null;
		end if;
		gv_dbu := k_dad_adm.map_dbuser(gv_dad);
	
		-- parse url_prefix
		if k_cfg_reader.front_server_ip = cgi('remote_addr') then
			gv_prefix := k_cfg_reader.front_server_prefix;
		elsif cgi('server_name') like 'XDB%' then
			gv_prefix := cgi('SCRIPT_NAME') || '/!s';
		else
			gv_prefix := cgi('pw_path_prefix');
		end if;
	
		-- parameter parse
		if gv_prog is null then
			return; -- if for static file, dont parse parameter
		end if;
		r.na := na;
		r.va := va;
		gv_params.delete;
		gv_cgi_envs.delete;
		gv_cookies.delete;
		for i in 1 .. na.count loop
			n := na(i);
			v := va(i);
			begin
				gv_params(n).extend;
				gv_params(n)(gv_params(n).count) := v;
			exception
				when no_data_found then
					gv_params(n) := st(v);
			end;
		end loop;
	
	end;

	procedure init_from_url(p_url varchar2) is
		n varchar2(100);
		v varchar2(32000);
	begin
		p.split(p_url, '?');
		p.split2(p.gv_st(p.gv_st.count) || '&', '&=');
		for i in 1 .. p.gv_values.count loop
			n := p.gv_texts(i);
			v := utl_url.unescape(p.gv_values(i), 'UTF8');
			begin
				gv_params(n).extend;
				gv_params(n)(gv_params(n).count) := v;
			exception
				when no_data_found then
					gv_params(n) := st(v);
			end;
		end loop;
	end;

	procedure init_from_pipe is
		v_result    number;
		na          owa.vc_arr;
		va          owa.vc_arr;
		v_count     number;
		v_pipe_name varchar2(100) := dbms_pipe.unique_session_name;
		v_params    st_arr;
	begin
		v_result := dbms_pipe.receive_message(v_pipe_name, 10);
		dbms_pipe.unpack_message(item => v_count);
		for i in 1 .. v_count loop
			v_result := dbms_pipe.receive_message(v_pipe_name, 1);
			dbms_pipe.unpack_message(na(i));
			dbms_pipe.unpack_message(va(i));
		end loop;
		gv_params := v_params;
		init(na, va);
	end;

	procedure setc(name varchar2, value varchar2) is
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

	function error_str(name varchar2) return varchar2 is
	begin
		return 'parameter [' || name || '] not exists and no default provided';
	end;

	procedure getc(name varchar2, value in out nocopy varchar2, defval varchar2) is
	begin
		value := gv_params(name) (1);
	exception
		when no_data_found then
			value := defval;
	end;

	procedure getc(name varchar2, value in out nocopy varchar2) is
	begin
		value := gv_params(name) (1);
	exception
		when no_data_found then
			raise_application_error(-20000, error_str(name));
	end;

	procedure getn(name varchar2, value in out nocopy number, defval number, format varchar2 := null) is
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

	procedure getn(name varchar2, value in out nocopy number, format varchar2 := null) is
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

	procedure getd(name varchar2, value in out nocopy date, defval date, format varchar2 := null) is
	begin
		value := to_date(gv_params(name) (1), nvl(format, gc_date_fmt));
	exception
		when no_data_found then
			value := defval;
	end;

	procedure getd(name varchar2, value in out nocopy date, format varchar2 := null) is
	begin
		value := to_date(gv_params(name) (1), nvl(format, gc_date_fmt));
	exception
		when no_data_found then
			raise_application_error(-20000, error_str(name));
	end;

	function getc(name varchar2, defval varchar2) return varchar2 is
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

	function getn(name varchar2, defval number, format varchar2) return number is
		v number;
	begin
		getn(name, v, defval, format);
		return v;
	end;

	function getn(name varchar2, format varchar2) return number is
		v number;
	begin
		getn(name, v, format);
		return v;
	end;

	function getd(name varchar2, defval date, format varchar2) return date is
		v date;
	begin
		getd(name, v, defval, format);
		return v;
	end;

	function getd(name varchar2, format varchar2) return date is
		v date;
	begin
		getd(name, v, format);
		return v;
	end;

	procedure gets(name varchar2, value in out nocopy st) is
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

	procedure cgi(name varchar2, value varchar2) is
	begin
		gv_cgi_envs(name) := value;
	end;

	function cgi(name varchar2) return varchar2 is
	begin
		return gv_cgi_envs(name);
	exception
		when others then
			gv_cgi_envs(name) := owa_util.get_cgi_env(name);
			return gv_cgi_envs(name);
	end;

	function cookie(name varchar2) return varchar2 is
		v_cookie owa_cookie.cookie;
	begin
		return gv_cookies(name);
	exception
		when others then
			v_cookie := owa_cookie.get(name);
			if v_cookie.num_vals = 0 then
				gv_cookies(name) := null;
			else
				gv_cookies(name) := v_cookie.vals(1);
			end if;
			return gv_cookies(name);
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
		return gv_dbu;
	end;

	function dad return varchar2 is
	begin
		if gv_dad is not null then
			return gv_dad;
		end if;
		if cgi('url_mode') is null then
			gv_dad := regexp_substr(cgi('path_info'), '^/!s/([^/]+)', 1, 1, '', 1);
		else
			gv_dad := cgi('dad_name');
		end if;
		return gv_dad;
	end;

	-- for outside use
	function dad_path return varchar2 is
	begin
		return 'http://' || cgi('HTTP_HOST') || gv_prefix || '/' || gv_dad;
	end;

	-- for internal url catacation
	function full_base return varchar2 is
	begin
		return dad_path || '/';
	end;

	function pack return varchar2 is
	begin
		return gv_pack;
	end;

	function proc return varchar2 is
	begin
		return gv_proc;
	end;

	function prog return varchar2 is
	begin
		return gv_prog;
	end;

	function file return varchar2 is
	begin
		return gv_file;
	end;

	function from_prog return varchar2 is
		v  varchar2(1000);
		v1 pls_integer;
		v2 pls_integer;
	begin
		v  := owa_util.get_cgi_env('http_referer');
		v1 := instr(v, '?');
		if v1 > 0 then
			v := substr(v, 1, v1 - 1);
		end if;
		v2 := instr(v, '/', -1);
		return substr(v, v2 + 1);
	end;

	function url return varchar2 is
		v_qstr varchar2(999) := cgi('query_string');
	begin
		return gv_prog || t.nnpre('?', v_qstr);
	end;

	function pw_path_prefix return varchar2 is
	begin
		return gv_prefix;
	end;

	function etag return varchar2 is
		v varchar2(100) := cgi('if-none-match');
	begin
		return substrb(v, 2, lengthb(v) - 2);
	end;

	function lmt return varchar2 is
		fmt  constant varchar2(100) := 'Dy, DD Mon YYYY HH24:MI:SS "GMT"';
		lang constant varchar2(100) := 'NLS_DATE_LANGUAGE = American';
	begin
		return to_date(cgi('if-modified-since'), fmt, lang) + nvl(owa_custom.dbms_server_gmtdiff, 0) / 24;
	end;

end r;
/

