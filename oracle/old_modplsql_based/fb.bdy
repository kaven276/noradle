create or replace package body fb is
	pragma serially_reusable;

	-- 准备初始化
	procedure info(p_succeed boolean, p_info varchar2) is
	begin
		if p_succeed then
			commit;
		elsif not p_succeed then
			rollback;
		end if;
	
		gv_succeed       := p_succeed;
		gv_feedback_info := p_info;
		gv_wizard_text   := st();
		gv_wizard_url    := st();
	end;

	procedure wizard(p_text varchar2, p_url varchar2) is
		v_cnt integer;
	begin
		v_cnt := gv_wizard_text.count + 1;
		gv_wizard_text.extend;
		gv_wizard_url.extend;
		gv_wizard_text(v_cnt) := p_text;
		gv_wizard_url(v_cnt) := p_url;
	end;

	procedure wizard_history(p_text varchar2 := null, p_steps pls_integer := 1, p_reload boolean := false) is
	begin
		wizard(nvl(p_text, '返回'),
					 'javascript:history.go(-' || p_steps || ');' || case when p_reload then 'location.reload(true);' end);
	end;

	procedure wizard_referer(p_text varchar2 := null) is
	begin
		wizard(nvl(p_text, '返回'), owa_util.get_cgi_env('http_referer'));
	end;

	procedure wizard_regen_page(p_text varchar2 := null) is
		v varchar2(4000) := owa_util.get_cgi_env('query_string');
	begin
		wizard(nvl(p_text, '重刷页面'), lower(owa_util.get_procedure) || case when v is not null then '?' || v end);
	end;

	-- 完全可以使用自定义的界面程序来输出反馈页，内容都是一样的.
	procedure print_page is
		v_path varchar2(100) := r.cgi('psp_url') || '/static/pub/fb/';
	begin
		p.h(r.cgi('psp_url') || '/static/pub/fb/fb.css,/psp.web/psp/static/pub/fb/fb.js', '反馈');
		p.table_open(rules => 'all');
		p.caption(p.el_open);
		p.img(v_path || case when gv_succeed then 'success.gif' when not gv_succeed then 'exception.gif' else
					'info_32.gif' end);
		p.span(gv_feedback_info);
		p.caption(p.el_close);
		for i in 1 .. gv_wizard_text.count loop
			p.tr_open;
			p.th(i);
			p.td(p.a(gv_wizard_text(i), gv_wizard_url(i)));
			p.tr_close;
		end loop;
		p.table_close;
	end;

end fb;
/

