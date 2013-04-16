create or replace package body auth_s is

	procedure login_simple(p_name varchar2) is
	begin
		s.login(p_name);
	end;

	procedure login_complex(p_name varchar2) is
	begin
		s.login(p_name, r.getc('company'), method => 'password');
		s.attr('maxidle', r.getn('maxidle'));
		s.attr('maxlive', r.getn('maxlive'));
		s.attr('attr1', r.getc('attr1'));
		s.attr('attr2', r.getc('attr2'));
	end;

	procedure logout is
	begin
		s.logout;
	end;

	procedure touch is
	begin
		s.touch;
	end;

	procedure clear is
	begin
		k_gac.grm('A#DEMO');
	end;

end auth_s;
/
