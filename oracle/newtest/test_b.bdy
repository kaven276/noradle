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

end test_b;
/

