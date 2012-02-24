create or replace package body k_cookie is

	function get(p_name varchar2) return varchar2 is
		v_cookie owa_cookie.cookie;
	begin
		v_cookie := owa_cookie.get(p_name);
		if v_cookie.num_vals = 0 then
			return 'null';
		else
			return v_cookie.vals(1);
		end if;
	end;

	function dad return varchar2 is
	begin
		return r.pw_path_prefix || '/' || r.dad;
		return r.cgi('SCRIPT_NAME') || '/';
	end;

	procedure send(p_name varchar2, p_value varchar2) is
	begin
		owa_cookie.send(name => p_name, value => p_value, path => r.dad);
	end;

	procedure install(p_name varchar2, p_value varchar2) is
	begin
		owa_cookie.send(name => p_name, value => p_value, path => dad, expires => to_date('2050-01-01', 'YYYY-MM-DD'));
	end;

	procedure remove(p_name varchar2, p_value varchar2) is
	begin
		owa_util.mime_header(bclose_header => false);
		owa_cookie.send(name => p_name, value => p_value, path => dad, expires => to_date('1990-01-01', 'YYYY-MM-DD'));
	
	end;

	procedure set_expire(p_name varchar2, p_date date) is
	begin
		owa_cookie.send(name => p_name, value => 'Y', path => dad, expires => to_date(p_date, 'YYYY-MM-DD'));
	end;

	procedure set_max_age(p_name varchar2, p_age number) is
	begin
		-- owa_util.status_line(304, bclose_header => false);
		owa_cookie.send(name => p_name, value => 'Y', path => dad, expires => sysdate + p_age / 24 / 60);
	end;

end k_cookie;
/

