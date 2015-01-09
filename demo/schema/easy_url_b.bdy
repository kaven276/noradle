create or replace package body easy_url_b is

	procedure d is
	begin
		x.o('<html>');
		x.o('<head>');
		x.l(' <link>', '*.css');
		x.j(' <script>', '*.js');
		x.j(' <script>', '^packs/url_test1_b/proc.js');
		x.o(' <style>');
		x.t('  a{display:block;line-height:1.5em;}');
		x.t('  p{margin:0.2em;}');
		x.t('  li{margin:0.5em;line-height:1.2em;}');
		x.c(' </style>');
		x.c('</head>');
		x.o('<body>');
	
		src_b.link_proc;
		x.p('<p>', 'r.prog=' || r.prog);
		x.p('<p>', 'r.pack=' || r.pack);
		x.p('<p>', 'r.proc=' || r.proc);
	
		x.p('<h3>', 'URL reference test suite includes the following items');
		x.o('<ol>');
		x.p(' <li>',
				'pack1.proc1-> pack1.proc2 : (other_proc) <br/>
				a packaged proc include another proc in the same package');
		x.p(' <li>',
				'pack1.procn-> pack2.procm : (other_proc_x, other_pack_x.other_proc) <br/>
				a packaged proc refers another packaged or standalone proc');
		x.p(' <li>',
				'pack1.proc1-> packs/pack1/proc1.ext : (.css, .js) <br/>
				a packaged proc refers it''s own one-to-one same-named js,css static files');
		x.p(' <li>',
				'pack1.procn-> packs/pack1/file.ext : (file.ext) <br/>
				a packaged/standalone proc refers it''s own static file ');
		x.p(' <li>',
				'any-> static/packn_or_procn/file.ext : (other_prog_x/file.ext) <br/>any code refers other packaged/standalone unit''s static files');
		x.p(' <li>',
				'pack1_b.procn-> pack1_c.procm : (@x.proc, @x/file.ext) <br/>
				refer same name unit but with a differ suffix, @ stand for name without _x suffix');
		x.p(' <li>',
				'any-> dir/file.txt : (dir/file.ext) <br/>
		    refer my dad/app''s normal static file');
	
		x.p(' <li>', '(./file.ext) <br/>refer my dad/app''s static file in root dir');
		x.p(' <li>', '(../app/..., \app/...) <br/>refer other dad/app''s normal static file');
		x.p(' <li>', '(/...) <br/>refer my http server''s path from root "/" ');
		x.p(' <li>', '( xxx://.../... ) <br/>refer other website''s url');
		x.p(' <li>',
				'([prefix_key]/path) <br/> refer other website''s url using re-allocatable key who maps to url prefix');
		x.p(' <li>',
				'allow static service to switch from between internal(same as plsql dynamic page server) and external servers, or move between external servers ');
		x.p(' <li>', 'switch [prefix] to third party''s backup path');
		x.c('</ol>');
	
		x.t('<br/>');
	
		x.t('<br/>');
		x.p('<p>', '>>> Links to other dynamic pages.');
		x.a('<a>', 'proc1 in @x.proc form', '@b.proc1');
		x.a('<a>', 'easy_url_b.proc2 in pack.proc form', 'easy_url_b.proc2?p_b=ab.c&p1=LiYong');
		x.a('<a>', 'to standalone proc 1', 'url_test1_b');
		x.a('<a>', 'to standalone proc 2', 'url_test2_b');
		x.a('<a>', 'easy_url_b.proc2 in =pack.proc form', 'easy_url_b.proc2?p_b=ab.c&p1=LiYong');
		x.a('<a>', 'to standalone proc in =proc', '=url_test1_b');
	
		x.t('<br/>');
		x.p('<p>', '>>> Links to static files.');
		x.p('<p>', 'this is myself''s img (CHN.gif)' || x.i('<img>', '@b/CHN.gif'));
		x.p('<p>', 'this is url_b''s img (url_b/CHN.gif)' || x.i('<img>', '^packs/url_b/CHN.gif'));
		x.p('<p>', 'this is url_test1_b''s img (url_test1_b/USA.gif)' || x.i('<img>', '^packs/url_test1_b/USA.gif'));
		x.p('<p>', 'this is url_test2_b''s img (url_test2_b/RUS.gif)' || x.i('<img>', '^packs/url_test2_b/RUS.gif'));
		x.p('<p>', 'this is ico/''s img (ico/google.ico)' || x.i('<img>', '^ico/google.ico'));
		x.p('<p>', 'this is img/nations/''s img (img/nations/JPN.gif)' || x.i('<img>', '^img/nations/JPN.gif'));
		x.p('<p>', 'this is app/dad''s root/''s img (./GER.gif)' || x.i('<img>', '^GER.gif'));
		x.p('<p>',
				'this is other dad''s img using  \ (\demo/packs/url_b/CHN.gif)' ||
				x.i('<img>', '\' || r.dbu || '/packs/url_b/CHN.gif'));
	
		x.t('<br/>');
		x.p('<p>', '>>> Links to other site''s resources');
		x.p('<p>',
				'this is outsite''s img ([myself]/demo/img/nations/ITA.gif)' ||
				x.i('<img>', '[myself]' || '/demo/img/nations/ITA.gif'));
		x.p('<p>',
				'this is for abs path (http://www.oracleimg.com/us/assets/oralogo-small.gif)' ||
				x.i('<img>', 'http://www.oracleimg.com/us/assets/oralogo-small.gif'));
	
		x.t('<br/>');
		x.p('<p>', '>>> Links to other url schemas');
		x.p('<p>',
				x.a('<a>', 'javascript', 'javascript:alert("link to javascript")') || '(javascript:alert("link to javascript")');
	
		x.c('</body>');
		x.c('</html>');
	end;

	procedure proc1 is
		n varchar2(100);
		v varchar2(999);
	begin
		pc.h;
		src_b.link_proc;
		x.o('<form name=f,action=proc2>');
		x.s(' <input type=text,name=p1>');
		x.c('</form>');
	
		x.p('<h4>', 'http headers');
		x.o('<pre>');
		n := ra.params.first;
		loop
			exit when n is null;
			v := ra.params(n) (1);
			h.line(n || ' : ' || v);
			n := ra.params.next(n);
		end loop;
		x.c('</pre>');
	end;

	procedure proc2 is
	begin
		pc.h;
		src_b.link_proc;
		x.p('<style>', 'a{display:block;}');
		x.p('<p>', r.getc('p1', '[null]'));
		x.a('<a>', 'back', 'javascript:history.back();');
		x.a('<a>', 'home', 'd');
	end;

end easy_url_b;
/
