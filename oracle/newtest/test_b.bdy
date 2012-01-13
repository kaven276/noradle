create or replace package body test_b is

	procedure d is
	begin
		p.prepare;
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
		p.prepare(mime_type => 'text/html');
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

end test_b;
/
