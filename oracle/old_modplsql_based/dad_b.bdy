create or replace package body dad_b is

	procedure d is
	begin
		select max(a.dad_name) into tmp.s from dad_t a where a.disp_order = 0;
		if tmp.s is not null and true then
			p.go('/' || tmp.s);
		end if;
		p.meta_init;
		p.meta_name('keywords', '企号通部署清单');
		p.meta_name('viewport', 'user-scalable=no,width=device-width,initial-scale=1,minimum-scale=1.0,maximum-scale=1.0');
	
		p.h('', 'PSP.WEB APPS');
		p.css('a{text-decoration:none;}');
		for i in (select * from dad_t a where a.disp_order is not null order by a.disp_order, a.dad_name) loop
			p.p(p.a('【' || i.dad_name || '】', r.pw_path_prefix || '/' || i.dad_name));
			p.p(i.comments);
		end loop;
	end;

end dad_b;
/

