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
		h.set_cookie('bsid', 'myself', path => r.dir || 'test_b.d');
	
		h.header('a', 1);
		h.header_close;
	
		pc.h;
		x.o('<style>');
		h.line('p{line-height:1.1em;margin:0px;}');
		x.c('</style>');
		x.p('<p>', 'test case that none ascii charset following http header');
		x.p('<p>', r.hostname);
		x.p('<p>', r.port);
		x.p('<p>', r.method);
		x.p('<p>', r.prog);
		x.p('<p>', r.pack);
		x.p('<p>', r.proc);
		x.p('<p>', r.qstr);
	
		h.line('<br/>');
		h.line(r.header('accept-encoding'));
		h.line('<br/>');
		-- h.line(to_char(r.lmt, 'yyyy-mm-dd hh24:mi:ss'));
		h.line('<br/>');
		-- h.line(r.etag);
		x.t('<br/>');
		x.a('<a>', 'self', r.prog || r.qstr);
	
		for i in 1 .. r.getn('count', 10) loop
			x.p('<p>', i);
		end loop;
	end;

	procedure form is
	begin
		h.content_type(charset => 'gbk');
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
			
				h.line(r.getc('text_input'));
				h.line(r.getc('checkbox_input'));
				r.gets('checkbox_input', v_st);
				for i in 1 .. v_st.count loop
					h.line(v_st(i));
				end loop;
				h.line(r.getc('password_input'));
				h.line(r.getc('button1'));
				h.line(r.getc('type'));
				h.line(r.gets('type') (2));
			
				h.line('');
				h.line('http headers');
				h.line(r.header('accept'));
				h.line(r.header('accept-charset'));
				h.line(r.header('accept-encoding'));
				h.line(r.header('accept-language'));
				h.line(r.header('connection'));
			
				h.line('');
				h.line('cookies');
				h.line(r.cookie('ck1'));
				h.line(r.cookie('ck2'));
				h.line(r.cookie('ck3'));
				h.line(r.cookie('ck4'));
			when 'GET' then
				h.status_line(303);
				h.location('test_b.entry');
				h.header_close;
			else
				h.status_line(200);
				h.content_type;
				h.header_close;
				h.line('Method (' || r.method || ') is not supported');
		end case;
	end;

end test_b;
/
