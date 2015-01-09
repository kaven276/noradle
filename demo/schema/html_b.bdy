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
	
		x.t('<!DOCTYPE html>');
		x.o('<html>');
		x.o('<head>');
		y.embed(r.getc('tag', '<style>'));
		x.c('</head>');
		x.o('<body>');
		src_b.link_proc;
		x.o('<div#wrapper>');
		y.lcss_ctx('div#wrapper');
		y.lcss('{margin:0px;background-color:#EEE;}');
	
		x.o('<div#text style=border:1px solid silver;width:80%;padding:8px 20px;>');
		for i in 1 .. 6 loop
			x.p('<h' || i || '>', 'header ' || i);
			x.p('<p>', 'a paragraph');
		end loop;
		x.c('</div>');
	
		x.o('<ul#ul>');
		for i in c_packages loop
			x.p('<li>', i.object_name);
		end loop;
		x.c('</ul>');
	
		x.o('<ol#ol>');
		for i in c_packages loop
			x.p('<li>', i.object_name);
		end loop;
		x.c('</ol>');
	
		x.o('<dl>');
		for i in c_packages loop
			x.p('<dt>', i.object_name);
			x.p('<dd>', t.d2s(i.created));
		end loop;
		x.c('</dl>');
	
		x.t('<hr/>');
	
		x.o('<table rules=all,cellspacing=0,cellpadding=5,style=border:1px solid silver;>');
		x.p('<caption>', 'table example');
		x.o(' <thead>');
		x.p('  <tr>', m.w('<th>@</th>', st('package name', 'created')));
		x.c(' </thead>');
		x.o(' <tbody>');
		for i in c_packages loop
			x.o('<tr>');
			x.p(' <td>', i.object_name);
			x.p(' <td>', t.d2s(i.created));
			x.c('</tr>');
		end loop;
		x.c(' </tbody>');
		x.c('</table>');
	
		x.o('<field>');
		x.p(' <legend>', 'form example');
		x.o(' <form name=f,action=html_b.action,target=_blank,method=get>');
		x.p('  <label>', 'your name' || x.s('<input type=text,name=name>'));
		x.p('  <label>', 'your password' || x.s('<input type=password,name=pass>'));
		x.s('  <input type=submit>');
		x.c(' </form>');
		x.c('</field>');
	
		x.c('</div>');
	
		for i in 1 .. r.getn('count', 0) loop
			x.p('<p>', i);
		end loop;
	end;

	procedure component_css is
		v_link boolean;
	
		procedure component1 is
		begin
			x.o('<div#id1>');
			y.lcss_ctx('#id1');
			y.lcss('p{line-height:1.5em;margin:0px 2em;color:gray;}');
			x.p('<p>',
					'This is div component with some p in it, This div component can control it''s css within itself,' ||
					'no matter which page include the div, the css assosiated with the div is there.');
			x.c('</div>');
		end;
	
		procedure component2 is
		begin
			x.o('<form#id2>');
			y.lcss_ctx('#id2');
			y.lcss('{border:3px solid blue;border-radius:12px;}');
			y.lcss('input {border:1px solid silver;}');
			x.p('  <label>', 'label' || x.s('<input type=text,name=n,value=text>'));
			x.c('</form>');
		end;
	
	begin
		h.content_encoding_try_zip;
		x.t('<!DOCTYPE html>');
		x.o('<html>');
		x.o('<head>');
		x.p(' <title>', 'component css');
		case r.getc('link', '')
			when 'Y' then
				y.embed(r.getc('tag', '<link>'));
			when 'N' then
				y.embed(r.getc('tag', '<style>'));
			else
				null;
		end case;
		x.c('</head>');
		x.o('<body>');
	
		src_b.link_proc;
		component1;
		component2;
	end;

	procedure regen_page is
	begin
		pc.h;
		x.p('<p>', 'This is the first generated page.');
	
		h.print_init(true); -- this line will reset page output
		pc.h;
		src_b.link_proc;
		x.p('<p>', 'This is the second generated page that replace the first generated page.');
	end;

	procedure component is
		v_dhc boolean := h.written = 0;
	begin
		if v_dhc then
			pc.h;
			src_b.link_proc;
			x.p('<p>', 'I''m in direct http access mode.');
		else
			x.t('<br/>');
			src_b.link_proc('html_b.component');
			x.p('<p>', 'I''m included in ' || r.prog || ' as a component.');
		end if;
		x.p('<p>', 'My proc name is html_b.component.');
		x.p('<p>', 'Use direct http access to component is good for reuse and testing.');
	end;

	procedure complex is
	begin
		pc.h;
		src_b.link_proc;
		x.p('<p>', 'I''m a page composed of components');
		component;
		x.t('<br/>');
	end;

end html_b;
/
