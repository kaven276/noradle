create or replace package body psp_page_header_b is

	gv_printed boolean := false;

	function get_schema(p_prog varchar2) return varchar2 is
		v_psp_user varchar2(30) := sys_context('userenv', 'current_schema');
	begin
		if p_prog like v_psp_user || '_%' then
			return v_psp_user;
		else
			return user;
		end if;
	end;

	procedure get_prog
	(
		p_schema out varchar2,
		p_prog   out varchar2
	) is
		v_psp_user varchar2(30) := sys_context('userenv', 'current_schema');
	begin
		p_prog := owa_util.get_procedure;
		if p_prog like v_psp_user || '_%' then
			p_schema := v_psp_user;
		else
			p_schema := user;
		end if;
	end;

	procedure print(p_prog varchar2 := null) is
		v        pbld_page_header%rowtype;
		v_prog   varchar2(61);
		v_schema varchar2(30) := get_schema(v_prog);
	begin
		if gv_printed then
			-- prevent subprogram recall this method, help developer quickly find this error
			raise_application_error(-20000, 'Coding Error, repeat header print in the same page');
		end if;

		p.doc_type;
		p.html_open;
		p.head_open;

		if p_prog is null then
			v_prog := owa_util.get_procedure;
		else
			v_prog := upper(p_prog);
		end if;

		begin
			select t.*
				into v
				from pbld_page_header t
			 where t.schema = v_schema
				 and t.page = v_prog;

			if v.title is not null then
				p.title(v.title);
			end if;
			if v.anytext is not null then
				p.print(v.anytext);
			end if;
			if v.css is not null then
				p.link('psp_page_header_b.linked_css?p_page=' || v.page);
			end if;
			if v.js is not null then
				p.script('psp_page_header_b.linked_js?p_page=' || v.page);
			end if;
		exception
			when no_data_found then
				null;
		end;

		p.head_close;
		p.body_open;
	end;

	procedure linked_css(p_page varchar2) is
		v_css_text pbld_page_header.css%type;
		v_schema   varchar2(30) := get_schema(p_page);
	begin
		owa_util.mime_header(ccontent_type => 'text/stylesheet', bclose_header => true);
		begin
			select t.css
				into v_css_text
				from pbld_page_header t
			 where t.schema = v_schema
				 and t.page = p_page;
			htp.prn(v_css_text);
		exception
			when no_data_found then
				null;
		end;
	end;

	procedure linked_js(p_page varchar2) is
		v_js_text pbld_page_header.js%type;
		v_schema  varchar2(30) := get_schema(p_page);
	begin
		owa_util.mime_header(ccontent_type => 'text/javascript', bclose_header => true);
		begin
			select t.js
				into v_js_text
				from pbld_page_header t
			 where t.schema = v_schema
				 and t.page = p_page;
			htp.prn(v_js_text);
		exception
			when no_data_found then
				null;
		end;
	end;

	procedure edit_form(p_page varchar2) is
		v pbld_page_header%rowtype;
	begin
		v.page := p_page;
		psp_page_header_b.print;
		p.a(p_page, 'psp_page_test_b.para_form?p_page=' || p_page);

		begin
			select t.*
				into v
				from pbld_page_header t
			 where t.schema = user
				 and t.page = v.page;
		exception
			when no_data_found then
				null;
		end;

		p.form_open(n, 'psp_page_header_b.edit_main_handler?p_page=' || v.page, method => 'post');
		p.input_submit(n, '保存基本配置');
		p.br;
		p.label('title:');
		p.input_text('p_title', v.title);
		p.label('anytext:');
		p.br;
		p.textarea('p_anytext', v.anytext, rows => 5, cols => 80);
		p.form_close;

		p.form_open(n, 'psp_page_header_b.edit_css_handler?p_page=' || v.page, method => 'post');
		p.input_submit(n, '保存样式表');
		p.br;
		p.textarea('p_css', v.css, rows => 20, cols => 80);
		p.form_close;

		p.form_open(n, 'psp_page_header_b.edit_js_handler?p_page=' || v.page, method => 'post');
		p.input_submit(n, '保存脚本');
		p.br;
		p.textarea('p_js', v.js, rows => 20, cols => 80);
		p.form_close;

		p.html_tail;
	end;

	-- private
	procedure ensure_exist_record(p_page varchar2) is
		v_cnt integer;
	begin
		select count(*)
			into v_cnt
			from pbld_page_header t
		 where t.schema = user
			 and t.page = p_page;
		if v_cnt = 0 then
			insert into pbld_page_header (schema, page) values (user, p_page);
		end if;
	end;

	procedure edit_main_handler
	(
		p_page    varchar2,
		p_title   varchar2,
		p_anytext varchar2
	) is
	begin
		ensure_exist_record(p_page);
		update pbld_page_header t
			 set t.title   = p_title,
					 t.anytext = p_anytext
		 where t.schema = user
			 and t.page = p_page;
		owa_util.redirect_url(owa_util.get_cgi_env('http_referer'), true);
	end;

	procedure edit_css_handler
	(
		p_page varchar2,
		p_css  varchar2
	) is
	begin
		ensure_exist_record(p_page);
		update pbld_page_header t
			 set t.css = p_css
		 where t.schema = user
			 and t.page = p_page;
		owa_util.redirect_url(owa_util.get_cgi_env('http_referer'), true);
	end;

	procedure edit_js_handler
	(
		p_page varchar2,
		p_js   varchar2
	) is
	begin
		ensure_exist_record(p_page);
		update pbld_page_header t
			 set t.js = p_js
		 where t.schema = user
			 and t.page = p_page;
		owa_util.redirect_url(owa_util.get_cgi_env('http_referer'), true);
	end;

end psp_page_header_b;
/

