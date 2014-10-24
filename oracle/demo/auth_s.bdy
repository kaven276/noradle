create or replace package body auth_s is

	procedure login_simple(p_name varchar2) is
	begin
		r.setc('s$username', p_name);
	end;

	procedure login_complex(p_name varchar2) is
	begin
		r.setc('s$company', r.getc('company'));
		r.setc('s$username', p_name);
		r.setc('s$method', 'password');
		r.setd('s$ltime', sysdate);
		r.setn('s$maxidle', r.getn('maxidle'));
		r.setn('s$maxlive', r.getn('maxlive'));
		r.setc('s$attr1', r.getc('attr1'));
		r.setc('s$attr2', r.getc('attr2'));
	end;

	function user_name return varchar2 is
	begin
		return r.getc('s$username');
	end;

	function login_time return date is
	begin
		return r.getd('s$ltime');
	end;

	procedure logout is
	begin
		if not r.is_null('s$IDLE') then
			r.setc('s$BSID', '');
		end if;
	end;

end auth_s;
/
