create or replace package body tree_b is

	procedure emp_hier is
		cur sys_refcursor;
	begin
		x.o('<html>');
		x.o('<body>');
		src_b.link_proc;
		x.p('<h2>', 'use m.p, m.ro, tree.content(sys_refcursor), m.rc to print tree');
		
		x.o('<ul>');
		m.p(' <li class="xing-@"><a href="see?pid=@">@</a>|</li>', '<ul>', tmp.stv);
		m.ro(true);
		open cur for
			select level, substr(a.name, 1, 1), a.pid, a.name
				from emp_t a
			 start with a.name = 'Li Xinyan'
			connect by a.ppid = prior a.pid;
		tree.content(tmp.stv, cur);
		m.rc(tmp.stv);
	
		m.p(' <li class="xing-@"><b>@</b>|</li>', '<ul>', tmp.stv);
		m.ro(pretty => true);
		open cur for
			select level, substr(a.name, 1, 1), a.name
				from emp_t a
			 start with a.name = 'Li Yong'
			connect by a.ppid = prior a.pid;
		tree.content(tmp.stv, cur);
		m.rc(tmp.stv);
		x.c('</ul>');
	end;

end tree_b;
/
