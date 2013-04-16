create or replace package body html_b is

	procedure d is
		cursor c_packages is
			select * from user_objects a where a.object_type = 'PACKAGE' order by a.object_name asc;
	begin
		h.status_line;
		h.content_type(charset => 'utf-8');
		-- h.transfer_encoding_chunked;
		-- h.content_encoding_identity;
		h.header_close;
	
		p.comp_css_link(false);
		p.h;
		src_b.link_proc;
		p.div_open(id => 'wrapper');
		p.lcss('{margin:0px;background-color:#EEE;}');
	
		p.div_open(id => 'text', ac => st('#border:1px solid silver;width:80%;padding:8px 20px;'));
		for i in 1 .. 6 loop
			p.hn(i, 'header ' || i);
			p.p('a paragraph');
		end loop;
		p.div_close;
	
		p.ul_open(id => 'ul');
		for i in c_packages loop
			p.li(i.object_name);
		end loop;
		p.ul_close;
	
		p.ol_open(id => 'ul');
		for i in c_packages loop
			p.li(i.object_name);
		end loop;
		p.ol_close;
	
		p.dl_open;
		for i in c_packages loop
			p.dt(i.object_name);
			p.dd(t.d2s(i.created));
		end loop;
		p.dl_close;
	
		p.hr;
	
		p.table_open(rules => 'all', cellspacing => 0, cellpadding => 5, ac => st('#border:1px solid silver;'));
		p.caption('table example');
		p.thead_open;
		p.tr(p.ths(st('package name', 'created')));
		p.thead_close;
		p.tbody_open;
		for i in c_packages loop
			p.tr_open;
			p.td(i.object_name);
			p.td(t.d2s(i.created));
			p.tr_close;
		end loop;
		p.tbody_close;
		p.table_close;
	
		p.fieldset_open;
		p.legend('form example');
		p.form_open('f', 'action', '_blank', method => 'get');
		p.input_text('name', label_ex => 'your name');
		p.input_password('pass', label_ex => 'your password');
		p.input_submit;
		p.form_close;
		p.fieldset_close;
	
		p.div_close;
	
		for i in 1 .. r.getn('count', 0) loop
			p.p(i);
		end loop;
	end;

	procedure component_css is
		v_link boolean;
	
		procedure component1 is
		begin
			p.div_open(id => 'id1');
			p.lcss('p{line-height:1.5em;margin:0px 2em;color:gray;}');
			p.p('This is div component with some p in it, This div component can control it''s css within itself,' ||
					'no matter which page include the div, the css assosiated with the div is there.');
			p.div_close;
		end;
	
		procedure component2 is
		begin
			p.form_open(id => 'id2');
			p.lcss('{border:3px solid blue;border-radius:12px;}');
			p.lcss('input {border:1px solid silver;}');
			p.input_text('n', 'text', 'label');
			p.form_close;
		end;
	
	begin
		case r.getc('link', '')
			when 'Y' then
				v_link := true;
			when 'N' then
				v_link := false;
			else
				v_link := null;
		end case;
		h.content_encoding_try_zip;
		p.comp_css_link(v_link);
		p.h('', 'component css');
		src_b.link_proc;
		component1;
		component2;
	end;

	procedure regen_page is
	begin
		p.h;
		p.p('This is the first generated page.');
	
		p.init; -- this line will reset page output
		p.h;
		src_b.link_proc;
		p.p('This is the second generated page that replace the first generated page.');
	end;

	procedure component is
		v_dhc boolean := p.is_dhc;
	begin
		p.h;
		if v_dhc then
			src_b.link_proc;
			p.p('I''m in dhc(direct http access) mode.');
		else
			p.br;
			src_b.link_proc('html_b.component');
			p.p('I''m included in ' || r.prog || ' as a component.');
		end if;
		p.p('My proc name is html_b.component.');
		p.p('Use direct http access to component is good for reuse and testing.');
	end;

	procedure print_cgi_env is
	begin
		p.format_src;
		p.h;
		src_b.link_proc('html_b.print_cgi_env');
		p.br;
		p.pre_open;
		p.print_cgi_env;
		p.pre_close;
	end;

	procedure complex is
	begin
		p.format_src;
		p.h;
		src_b.link_proc;
		p.p('I''m a page composed of components');
		component;
		p.br;
		print_cgi_env;
	end;

end html_b;
/
