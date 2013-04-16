create or replace procedure url_test2_b is
begin
  p.h;
  p.p('I''m a standalone procedure 2');
  p.css('a{display:block;}');
  p.css('p{margin:0.2em;}');

  p.p('r.prog=' || r.prog);
  p.p('r.pack=' || r.pack);
  p.p('r.proc=' || r.proc);

  p.hr;

  p.a('d in pack.proc form', 'url_b.d');
  p.a('to another standalone proc', 'url_test1_b');

  p.hr;

  p.p('this is myself''s img ' || p.img('RUS.gif'));
  p.p('this is url_b''s img ' || p.img('url_b/CHN.gif'));
  p.p('this is url_test1_b''s img ' || p.img('url_test1_b/USA.gif'));
  p.p('this is url_test2_b''s img ' || p.img('url_test2_b/RUS.gif'));
  p.p('this is img/nations/''s img ' || p.img('img/nations/JPN.gif'));
  p.p('this is root/''s img ' || p.img('./GER.gif'));
end url_test2_b;
/
