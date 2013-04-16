create or replace procedure url_test1_b is
begin
	p.h('url_b/d.css,.css,.js');
	p.p('I''m a standalone procedure 1');
	p.css('a{display:block;}');
	p.css('p{margin:0.2em;}');

	p.p('r.prog=' || r.prog);
	p.p('r.pack=' || r.pack);
	p.p('r.proc=' || r.proc);

	p.hr;

	p.a('proc1 in pack.proc form', 'url_b.proc1');
	p.a('to another standalone proc', 'url_test2_b');

	p.hr;

	p.p('this is myself''s img ' || p.img('USA.gif'));
	p.p('this is url_b''s img ' || p.img('url_b/CHN.gif'));
	p.p('this is url_test1_b''s img ' || p.img('url_test1_b/USA.gif'));
	p.p('this is url_test2_b''s img ' || p.img('url_test2_b/RUS.gif'));
	p.p('this is img/nations/''s img ' || p.img('img/nations/JPN.gif'));
	p.p('this is root/''s img ' || p.img('./GER.gif'));

end url_test1_b;
/
