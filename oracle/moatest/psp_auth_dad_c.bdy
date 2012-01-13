create or replace package body psp_auth_dad_c is

	procedure auth is
	begin
		dbms_epg.authorize_dad(owa_util.get_cgi_env('dad_name'));
		commit;
		p.html_head(title => '授权成功');
	end;

	procedure deauth is
	begin
		dbms_epg.deauthorize_dad(owa_util.get_cgi_env('dad_name'));
		commit;
		p.html_head(title => '回收成功');
	end;

end psp_auth_dad_c;
/

