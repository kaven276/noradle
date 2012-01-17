create or replace package body r is

	gc_date_fmt constant varchar2(21) := 'yyyy-mm-dd hh24:mi:ss';

	type st_arr is table of st index by varchar2(100);
	gv_params st_arr;

	type str_arr is table of varchar2(1000) index by varchar2(100);
	gv_headers  str_arr;
	gv_cgi_envs str_arr;
	gv_cookies  str_arr;

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
	
		gv_params.delete;
		gv_cgi_envs.delete;
		gv_cookies.delete;
	
		-- read headers
		loop
			v_name  := utl_tcp.get_line(c, true);
			v_value := utl_tcp.get_line(c, true);
			exit when v_name is null and v_value is null;
		end loop;
	
		-- read cookies
		loop
			v_name  := utl_tcp.get_line(c, true);
			v_value := utl_tcp.get_line(c, true);
			exit when v_name is null and v_value is null;
		end loop;
	
		-- read parameters   
		loop
			v_name  := utl_tcp.get_line(c, true);
			v_value := utl_tcp.get_line(c, true);
			exit when v_name is null and v_value is null;
			t.split(v_st, v_value, ',');
			gv_params(v_name) := v_st;
		end loop;
	
		if v_method = 'POST' then
			loop
				v_name  := utl_tcp.get_line(c, true);
				v_value := utl_tcp.get_line(c, true);
				exit when v_name is null and v_value is null;
				t.split(v_st, v_value, ',');
				gv_params(v_name) := v_st;
			end loop;
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
end r;
/
