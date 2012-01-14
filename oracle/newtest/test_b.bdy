create or replace package body test_b is

	procedure d is
	begin
		p.status_line;
		p.content_type;
		p.http_header_close;
		p.line(r.host_prefix);
		p.line(r.port);
		p.line(r.method);
		p.line(r.base);
		p.line(r.dad);
		p.line(r.prog);
		p.line(r.pack);
		p.line(r.proc);
		p.line(r.path);
		p.line(r.qstr);
		p.line(r.hash);
	
		for i in 1000 .. 1099 loop
			p.line('<br/>' || i);
		end loop;
	end;

	procedure long_job is
	begin
		p.status_line;
		p.content_type(mime_type => 'text/html');
		p.http_header_close;
		p.line('<div id="cnt"></div>');
		p.line('<script>var cnt=document.getElementById("cnt");</script>');
		p.line('<pre>');
		for i in 1 .. 9 loop
			p.line('LiNE, NO.' || i);
			p.line('<script>cnt.innerText=' || i || ';</script>');
			-- p.line(rpad(i, 300, i));
			p.flush();
			dbms_lock.sleep(1);
		end loop;
		p.line('</pre>');
	end;

	procedure form is
	begin
		p.status_line(200);
		p.content_type;
		p.http_header_close;
		p.line('<a href="test_b.redirect">Link to test_b.redirect</a>');
		p.line('<form action="test_b.redirect" method="post">');
		p.line('<input type="submit"/>');
		p.line('</form>');
	end;

	procedure redirect is
	begin
		case r.method
			when 'POST' then
				p.go('test_b.d');
			when 'GET' then
				p.status_line(303);
				p.location('test_b.d');
				p.http_header_close;
			else
				p.status_line(200);
				p.content_type;
				p.http_header_close;
				p.line('Method (' || r.method || ') is not supported');
		end case;
	end;

end test_b;
/
