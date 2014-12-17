create or replace package body url_b is

	procedure d is
	begin
		x.o('<html>');
		x.o('<head>');
		x.l('<link>', '*.css');
		x.j('<script>', '*.js');
		x.j('<script>', '^packs/url_test1_b/proc.js');
		x.o('<style rel=stylesheet>');
		x.t('a{display:block;line-height:1.5em;}');
		x.t('p{margin:0.2em;}');
		x.t('li{margin:0.5em;line-height:1.2em;}');
		x.c('</style>');
		x.c('</head>');
		x.o('<body>');
	
		src_b.link_proc;
		x.p('<p>', 'r.prog=' || r.prog);
		x.p('<p>', 'r.pack=' || r.pack);
		x.p('<p>', 'r.proc=' || r.proc);
	
		x.p('<h3>', 'URL reference test suite includes the following items:');
		p.ol_open;
		p.li('pack1.proc1-> pack1.proc2 : (other_proc) <br/>a packaged proc include another proc in the same package');
		p.li('pack1.procn-> pack2.procm : (other_proc_x, other_pack_x.other_proc) <br/>a packaged proc refers another packaged or standalone proc');
		p.li('pack1.proc1-> packs/pack1/proc1.ext : (.css, .js) <br/>a packaged proc refers it''s own one-to-one same-named js,css static files');
		p.li('pack1.procn-> packs/pack1/file.ext : (file.ext) <br/>a packaged/standalone proc refers it''s own static file ');
		p.li('any-> static/packn_or_procn/file.ext : (other_prog_x/file.ext) <br/>any code refers other packaged/standalone unit''s static files');
		p.li('pack1_b.procn-> pack1_c.procm : (@x.proc, @x/file.ext) <br/>refer same name unit but with a differ suffix, @ stand for name without _x suffix');
		p.li('any-> dir/file.txt : (dir/file.ext) <br/>refer my dad/app''s normal static file');
	
		p.li('(./file.ext) <br/>refer my dad/app''s static file in root dir');
		p.li('(../app/..., \app/...) <br/>refer other dad/app''s normal static file');
		p.li('(/...) <br/>refer my http server''s path from root "/" ');
		p.li('( xxx://.../... ) <br/>refer other website''s url');
		p.li('([prefix_key]/path) <br/> refer other website''s url using re-allocatable key who maps to url prefix');
		p.li('allow static service to switch from between internal(same as plsql dynamic page server) and external servers, or move between external servers ');
		p.li('switch [prefix] to third party''s backup path');
		p.ol_close;
	
		p.hr;
	
		p.br;
		p.p('>>> Links to other dynamic pages.');
		p.a('proc1 in proc form', 'proc1');
		p.a('proc1 in @x.proc form', '@b.proc1');
		p.a('url_b.proc2 in pack.proc form', 'url_b.proc2?p_b=ab.c&p1=LiYong');
		p.a('to standalone proc', 'url_test1_b');
	
		p.br;
		p.p('>>> Links to static files.');
		p.p('this is myself''s img (CHN.gif)' || p.img('CHN.gif'));
		p.p('this is url_b''s img (url_b/CHN.gif)' || p.img('url_b/CHN.gif'));
		p.p('this is url_test1_b''s img (url_test1_b/USA.gif)' || p.img('url_test1_b/USA.gif'));
		p.p('this is url_test2_b''s img (url_test2_b/RUS.gif)' || p.img('url_test2_b/RUS.gif'));
		p.p('this is ico/''s img (ico/google.ico)' || p.img('^ico/google.ico'));
		p.p('this is img/nations/''s img (img/nations/JPN.gif)' || p.img('^img/nations/JPN.gif'));
		p.p('this is app/dad''s root/''s img (./GER.gif)' || p.img('./GER.gif'));
		p.p('this is other dad''s img using ../ (../demo/img/nations/CAN.gif)' ||
				p.img('../' || r.dbu || '/img/nations/CAN.gif'));
		p.p('this is other dad''s img using  \ (\demo/packs/url_b/CHN.gif)' || p.img('\demo/packs/url_b/CHN.gif'));
	
		p.br;
		p.p('>>> Links to other site''s resources');
		p.p('this is outsite''s img ([myself]/demo/img/nations/ITA.gif)' ||
				p.img('[myself]' || '/demo/img/nations/ITA.gif'));
		p.p('this is for abs path (http://www.oracleimg.com/us/assets/oralogo-small.gif)' ||
				p.img('http://www.oracleimg.com/us/assets/oralogo-small.gif'));
	
		p.br;
		p.p('>>> Links to other url schemas');
		p.p(p.a('javascript', 'javascript:alert(''link to javascript'')', ac => st('#display:inline;')) ||
				'(javascript:alert(''link to javascript'')');
	
		x.c('</body>');
		x.c('</html>');
	end;

	procedure proc1 is
		n varchar2(100);
		v varchar2(999);
	begin
		p.h;
		src_b.link_proc;
		p.form_open('f', 'proc2');
		p.input_text('p1');
		p.form_close;
	
		p.hn(4, 'http headers');
		p.pre_open;
		n := ra.params.first;
		loop
			exit when n is null;
			v := ra.params(n) (1);
			h.line(n || ' : ' || v);
			n := ra.params.next(n);
		end loop;
		p.pre_close;
	end;

	procedure proc2 is
	begin
		p.h;
		src_b.link_proc;
		p.css('a{display:block;}');
		p.p(r.getc('p1', '[null]'));
		p.a('back', 'javascript:history.back();');
		p.a('home', 'd');
	end;

end url_b;
/
