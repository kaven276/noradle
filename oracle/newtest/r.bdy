create or replace package body r is

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

	type str_arr is table of varchar2(1000) index by varchar2(100);
	gv_headers str_arr;
	gv_cookies str_arr;

	procedure "_init"(c in out nocopy utl_tcp.connection, passport pls_integer) is
		v_name  varchar2(1000);
		v_value varchar2(1000);
	begin
		if passport != 80526 then
			raise_application_error(-20000, 'can not call psp.web''s internal method');
		end if;
	
		-- basic input
		v_hostp  := utl_tcp.get_line(c, true);
		v_port   := to_number(utl_tcp.get_line(c, true));
		v_method := utl_tcp.get_line(c, true);
		v_base   := utl_tcp.get_line(c, true);
		v_dad    := utl_tcp.get_line(c, true);
		v_prog   := utl_tcp.get_line(c, true);
		v_pack   := utl_tcp.get_line(c, true);
		v_proc   := utl_tcp.get_line(c, true);
		v_path   := utl_tcp.get_line(c, true);
		v_qstr   := utl_tcp.get_line(c, true);
		v_hash   := utl_tcp.get_line(c, true);
	
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
		end loop;
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

end r;
/

