create or replace procedure url_test2_b is
begin
	pc.h;
	x.p('<p>', 'I''m a standalone procedure 2');
	x.p('<style>', 'a{display:block;} p{margin:0.2em;}');

	x.p('<p>', 'r.prog=' || r.prog);
	x.p('<p>', 'r.pack=' || r.pack);
	x.p('<p>', 'r.proc=' || r.proc);

	x.t('<hr/>');

	x.a('<a>', 'd in pack.proc form', 'url_b.d');
	x.a('<a>', 'to another standalone proc 1', 'url_test1_b');

	x.t('<hr/>');

	x.p('<p>', 'this is myself''s img ' || x.i('<img>', '@b/RUS.gif'));
	x.p('<p>', 'this is url_b''s img ' || x.i('<img>', '^packs/url_b/CHN.gif'));
	x.p('<p>', 'this is url_test1_b''s img ' || x.i('<img>', '^packs/url_test1_b/USA.gif'));
	x.p('<p>', 'this is url_test2_b''s img ' || x.i('<img>', '^packs/url_test2_b/RUS.gif'));
	x.p('<p>', 'this is img/nations/''s img ' || x.i('<img>', '^img/nations/JPN.gif'));
	x.p('<p>', 'this is root/''s img ' || x.i('<img>', '^GER.gif'));
end url_test2_b;
/
