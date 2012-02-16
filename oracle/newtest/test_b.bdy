create or replace package body test_b is

	procedure d is
	begin
		h.status_line;
		h.content_type('text/html', charset => 'utf-8');
		h.content_language('zh-cn');
		-- h.content_md5_on;
		h.etag_md5_on;
		h.last_modified(trunc(sysdate));
		h.expires(sysdate + 1);
		h.etag('md5value');
		-- h.cookie2_send('bsid', '1234');
		-- h.cookie_send('msid', '1234');
	
		h.header('a', 1);
		-- h.transfer_encoding_chunked;
		-- h.content_encoding_gzip;
		h.http_header_close;
	
		p.init;
		p.http_header_close;
	
		p.style_open;
		p.line('p{line-height:1.1em;margin:0px;}');
		p.style_close;
		p.p('测试一下非ascii字符紧邻http header的情况');
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
		p.p(r.hash);
	
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

	procedure long_job is
	begin
		h.status_line;
		h.content_type(mime_type => 'text/html');
		h.write_head;
		p.line('<div id="cnt"></div>');
		p.line('<script>var cnt=document.getElementById("cnt");</script>');
		p.line('<pre>');
		for i in 1 .. 9 loop
			p.line('LiNE, NO.' || i);
			p.line('<script>cnt.innerText=' || i || ';</script>');
			-- p.line(rpad(i, 300, i));
			output.flush();
			dbms_lock.sleep(1);
		end loop;
		p.line('</pre>');
	end;

	procedure form is
	begin
		h.status_line(200);
		h.content_type(charset => 'gbk');
		-- p.content_type(charset => 'GBK');
		h.header('set-cookie', 'ck1=1234');
		h.header('set-cookie', 'ck3=5678');
		h.header('a', 1);
		h.header('b', 2);
		h.http_header_close;
	
		p.http_header_close;
		p.line('<a href="test_b.redirect">Link to test_b.redirect</a>');
		p.line('<form action="test_c.do_303_retry_alfter?type=both&type=bothtoo" method="post" accept-charset="gbk">');
		p.line('<input name="text_input" type="text" value="http://www.google.com?q=HELLO"/>');
		p.line('您好');
		p.line(utl_i18n.escape_reference('您好', 'us7ascii'));
		output.flush;
		p.line('<input name="checkbox_input" type="checkbox" value="checkedvalue1" checked="true"/>');
		p.line('<input name="checkbox_input" type="checkbox" value="checkedvalue2" checked="true"/>');
		p.line('<input name="password_input" type="password" value="passwordvalue"/>');
		p.line('<input name="button1" type="submit" value="save"/>');
		p.line('</form>');
	
		p.line('<a href="test_b.d">test_b.d</a>');
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
				h.http_header_close;
			
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
				h.status_line(200);
				h.content_type(mime_type => 'text/plain');
				h.http_header_close;
			
				p.line(r.getc('text_input'));
				p.line(r.getc('checkbox_input'));
				r.gets('checkbox_input', v_st);
				for i in 1 .. v_st.count loop
					p.line(v_st(i));
				end loop;
				return;
			
				h.status_line(303);
				h.location('test_b.d');
				h.write_head;
			else
				h.status_line(200);
				h.content_type;
				h.write_head;
				p.line('Method (' || r.method || ') is not supported');
		end case;
	end;

	procedure auth is
	begin
		if r.user is null or r.user != 'psp.web' then
			h.www_authenticate_basic('test');
			return;
		end if;
		h.status_line;
		h.content_type('text/plain', charset => 'utf-8');
		h.http_header_close;
		p.line(r.user);
		p.line(r.pass);
	end;

	procedure xhtp is
	begin
		h.status_line;
		h.content_type('text/html', charset => 'utf-8');
		h.http_header_close;
		p.init;
		p.doc_type('5');
		p.h;
		p.ul_open;
		-- p.css_link;
		p.li('abc');
		p.li('123');
		p.ul_close;
	end;

	procedure refresh is
	begin
		h.refresh(3, r.getc('to'));
		h.content_type('text/plain');
		h.http_header_close;
		p.line(t.dt2s(sysdate));
		p.line(r.getc('to'));
	end;

	procedure error is
	begin
		raise_application_error(-20000, 'some exception');
	end;

	procedure on_developing is
	begin
		h.sts_501_not_implemented;
		h.http_header_close;
		p.line('This page is under developing, please wait for release');
	end;

end test_b;
/
