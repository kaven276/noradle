create or replace package body tree_b is

	procedure emp_hier_cur is
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
		tree.cur(tmp.stv, cur);
		m.rc(tmp.stv);
	
		m.p(' <li class="xing-@"><b>@</b>|</li>', '<ul>', tmp.stv);
		m.ro(pretty => true);
		open cur for
			select level, substr(a.name, 1, 1), a.name
				from emp_t a
			 start with a.name = 'Li Xinyan'
			connect by a.ppid = prior a.pid;
		tree.cur(tmp.stv, cur);
		m.rc(tmp.stv);
		x.c('</ul>');
	end;

	procedure emp_hier_nodes is
		cur sys_refcursor;
	begin
		-- h.content_type('text/plain');
		x.o('<html>');
		x.o('<body>');
		src_b.link_proc;
		x.p('<h2>', 'use m.p, tree.o, tree.n(by level), tree.c to print tree');
	
		x.o('<ul>');
		m.p(' <li class="xing-@"><a href="see?pid=@">@</a>', tmp.stv);
		tr.o(true);
		for a in (select level, substr(a.name, 1, 1), a.pid, a.name
								from emp_t a
							 start with a.name = 'Li Xinyan'
							connect by a.ppid = prior a.pid) loop
			tr.n(a.level, m.r(tmp.stv, st(substr(a.name, 1, 1), a.pid, a.name)));
		end loop;
		tr.c;
	
		m.p(' <li class="xing-@"><b>@</b>', tmp.stv);
		tree.o(pretty => true);
		for a in (select level, a.name from emp_t a start with a.name = 'Li Xinyan' connect by a.ppid = prior a.pid) loop
			tree.n(a.level, m.r(tmp.stv, st(substr(a.name, 1, 1), a.name)));
		end loop;
		tree.c;
		x.c('</ul>');
	end;

	procedure menu is
	begin
		x.o('<html>');
		x.o('<body>');
		src_b.link_proc;
		x.p('<h2>', 'use m.p, tree.o, tree.n(by indent), tree.c to print tree');
	
		x.o('<ul>');
		tr.o(true);
		tr.n(1, '<li>' || x.a('<a>', 'file', '#'));
		tr.n(2, '<li>' || x.a('<a>', 'new', '#'));
		tr.n(2, '<li>' || x.a('<a>', 'open', '#'));
		tr.n(2, '<li>' || x.a('<a>', 'close', '#'));
		tr.n(3, '<li>' || x.a('<a>', 'close all', '#'));
		tr.n(3, '<li>' || x.a('<a>', 'close current', '#'));
		tr.n(2, '<li>' || x.a('<a>', 'save', '#'));
		tr.n(3, '<li>' || x.a('<a>', 'save all', '#'));
		tr.n(3, '<li>' || x.a('<a>', 'save current', '#'));
	
		tr.n(' ', '<li>' || x.a('<a>', 'file', '#'));
		tr.n('  ', '<li>' || x.a('<a>', 'new', '#'));
		tr.n('  ', '<li>' || x.a('<a>', 'open', '#'));
		tr.n('  ', '<li>' || x.a('<a>', 'close', '#'));
		tr.n('   ', '<li>' || x.a('<a>', 'close all', '#'));
		tr.n('   ', '<li>' || x.a('<a>', 'close current', '#'));
		tr.n('  ', '<li>' || x.a('<a>', 'save', '#'));
		tr.n('   ', '<li>' || x.a('<a>', 'save all', '#'));
		tr.n('   ', '<li>' || x.a('<a>', 'save current', '#'));
	
		tr.n(' <li>' || x.a('<a>', 'file', '#'));
		tr.n('  <li>' || x.a('<a>', 'new', '#'));
		tr.n('  <li>' || x.a('<a>', 'open', '#'));
		tr.n('  <li>' || x.a('<a>', 'close', '#'));
		tr.n('   <li>' || x.a('<a>', 'close all', '#'));
		tr.n('   <li>' || x.a('<a>', 'close current', '#'));
		tr.n('  <li>' || x.a('<a>', 'save', '#'));
		tr.n('   <li>' || x.a('<a>', 'save all', '#'));
		tr.n('   <li>' || x.a('<a>', 'save current', '#'));
	
		tr.n(' <li>', x.a('<a>', 'file', '#'));
		tr.n('  <li>', x.a('<a>', 'new', '#'));
		tr.n('  <li>', x.a('<a>', 'open', '#'));
		tr.n('  <li>', x.a('<a>', 'close', '#'));
		tr.n('   <li>', x.a('<a>', 'close all', '#'));
		tr.n('   <li>', x.a('<a>', 'close current', '#'));
		tr.n('  <li>', x.a('<a>', 'save', '#'));
		tr.n('   <li>', x.a('<a>', 'save all', '#'));
		tr.n('   <li>', x.a('<a>', 'save current', '#'));
	
		tr.c;
		x.c('</ul>');
	end;

end tree_b;
/
