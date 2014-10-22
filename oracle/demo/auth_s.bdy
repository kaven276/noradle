create or replace package body auth_s is

	procedure login_simple(p_name varchar2) is
	begin
		r.session('username', p_name);
	end;

	procedure login_complex(p_name varchar2) is
	begin
		r.session('company', r.getc('company'));
		r.session('username', p_name);
		r.session('method', 'password');
		r.session('ltime', to_char(sysdate, 'yyyy-mm-dd hh24:mi:ss'));
		r.session('maxidle', r.getc('maxidle'));
		r.session('maxlive', r.getc('maxlive'));
		r.session('attr1', r.getc('attr1'));
		r.session('attr2', r.getc('attr2'));
	end;

	function user_name return varchar2 is
	begin
		return r.session('username');
	end;

	function login_time return date is
	begin
		return to_date(r.session('ltime'), 'yyyy-mm-dd hh24:mi:ss');
	end;

	procedure logout is
	begin
		if r.session('IDLE') is not null then
			r.session('BSID', '');
		end if;
	end;

end auth_s;
/
