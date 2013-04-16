create or replace package body test_b is

	procedure entry is
	begin
		h.header_close;
		h.line('<pre>');
		h.line('<a href="test_b.d">Link to test_b.d (basic request info) </a>');
		h.line('<a href="test_b.redirect">Link to test_b.redirect (test for redirect)</a>');
		h.line('</pre>');
		h.line(r.protocol);
		h.line(r.client_addr);
		h.line(r.client_port);
		h.line(r.header('x-forwarded-proto'));
		h.line(r.header('x-forwarded-for'));
		h.line(r.header('x-forwarded-port'));
	end;

	procedure d is
	begin
		if r.getn('count', 0) = 404 then
			h.sts_404_not_found;
			h.header_close;
			h.writeln('resource with count=404 does not exits');
			g.cancel;
		end if;
	
		if r.getn('count', 0) = 403 then
			h.sts_403_forbidden;
			h.header_close;
			h.writeln('You have not the right to access resource with count=403');
			g.cancel;
		end if;
	
		-- h.allow_post;
		-- h.allow('POST,PUT');
		h.sts_200_ok;
		h.content_type('text/html', charset => 'utf-8');
		h.content_language('zh-cn');
		h.set_cookie('bsid', 'myself', path => '/' || r.dad || '/test_b.d');
	
		h.header('a', 1);
		h.header_close;
	
		p.h;
		p.style_open;
		p.line('p{line-height:1.1em;margin:0px;}');
		p.style_close;
		p.p('test case that none ascii charset following http header');
		p.p(r.host_prefix);
		p.p(r.port);
		p.p(r.method);
		p.p(r.base);
		p.p(r.dad);
		p.p(r.prog);
		p.p(r.pack);
		p.p(r.proc);
		p.p(r.path);
		p.p(r.qstr);
	
		p.line('<br/>');
		p.line(r.header('accept-encoding'));
		p.line('<br/>');
		-- p.line(to_char(r.lmt, 'yyyy-mm-dd hh24:mi:ss'));
		p.line('<br/>');
		-- p.line(r.etag);
		p.br;
		p.a('self', r.prog || r.qstr);
	
		for i in 1 .. r.getn('count', 10) loop
			p.p(i);
		end loop;
	end;

	procedure form is
	begin
		h.content_type(charset => 'gbk');
		-- p.content_type(charset => 'GBK');
		h.header_close;
	
		h.line('<a href="test_b.redirect">Link to test_b.redirect</a>');
		h.line('<form action="test_c.do?type=both&type=bothtoo" method="post" accept-charset="gbk">');
		h.line('<input name="text_input" type="text" value="http://www.google.com?q=HELLO"/>');
		h.line('Hello');
		h.line(utl_i18n.escape_reference('Hello', 'us7ascii'));
		h.flush;
		h.line('<input name="checkbox_input" type="checkbox" value="checkedvalue1" checked="true"/>');
		h.line('<input name="checkbox_input" type="checkbox" value="checkedvalue2" checked="true"/>');
		h.line('<input name="password_input" type="password" value="passwordvalue"/>');
		h.line('<input name="button1" type="submit" value="save"/>');
		h.line('</form>');
	end;

	procedure redirect is
		v_st st;
	begin
		case r.method
			when 'POST' then
				h.go('test_b.d');
				-- h.feedback;
				return;
			
				h.status_line(200);
				h.content_type(mime_type => 'text/plain', charset => 'gbk');
				h.header_close;
			
				p.line(r.getc('text_input'));
				p.line(r.getc('checkbox_input'));
				r.gets('checkbox_input', v_st);
				for i in 1 .. v_st.count loop
					p.line(v_st(i));
				end loop;
				p.line(r.getc('password_input'));
				p.line(r.getc('button1'));
				p.line(r.getc('type'));
				p.line(r.gets('type') (2));
			
				p.line('');
				p.line('http headers');
				p.line(r.header('accept'));
				p.line(r.header('accept-charset'));
				p.line(r.header('accept-encoding'));
				p.line(r.header('accept-language'));
				p.line(r.header('connection'));
			
				p.line('');
				p.line('cookies');
				p.line(r.cookie('ck1'));
				p.line(r.cookie('ck2'));
				p.line(r.cookie('ck3'));
				p.line(r.cookie('ck4'));
			when 'GET' then
				h.status_line(303);
				h.location('test_b.entry');
				h.header_close;
			else
				h.status_line(200);
				h.content_type;
				h.header_close;
				p.line('Method (' || r.method || ') is not supported');
		end case;
	end;

end test_b;
/
