create or replace package body css_prof_b is

	procedure bootstrap_load is
	begin
		x.t('<!DOCTYPE html>');
		x.o('<html>');
		x.o(' <head>');
		x.s('  <meta name=viewport,content=:1>', st('width=device-width, initial-scale=1'));
		x.l('  <link>', 'https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css');
		x.j('  <script>', '//cdn.bootcss.com/jquery/2.1.1/jquery.min.js');
		x.j('  <script>', 'https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/js/bootstrap.min.js');
		x.c(' </head>');
		x.o(' <body>');
	end;

	procedure main is
		p_paint    boolean := not r.is_null('paint');
		p_rule_cnt pls_integer := r.getn('rule_cnt', 1000);
		p_dom_cnt  pls_integer := r.getn('dom_cnt', 1000);
		p_wrap_cnt pls_integer := r.getn('wrap_cnt', 0);
		p_nest_cnt pls_integer := r.getn('nest_cnt', 0);
		v_loop_cnt pls_integer := ceil(p_dom_cnt / (p_nest_cnt + 1));
		p_rule_pat varchar2(1000) := r.getc('rule_pat', '.class:1{background-color:yellow;}');
	begin
		h.force_stream;
		x.t('<!DOCTYPE html>');
		x.o('<html>');
		x.o(' <head>');
		x.s('  <meta name=viewport,content=:1>', st('width=device-width, initial-scale=1'));
		x.p('  <script>', 'var t_head = Number(new Date());');
		x.o('  <style>');
		x.t('   label{display:block;}#topmost{display::1;}', st(t.tf(p_paint, 'block', 'none')));
		for i in 1 .. p_rule_cnt loop
			x.t(p_rule_pat, st(i));
		end loop;
		x.c('  </style>');
		x.c(' </head>');
		x.o(' <body>');
		src_b.link_proc;
		x.p('  <script>', 'var t_body = Number(new Date());');
		x.p('  <pre#log>', '');
	
		x.o('  <form action=:1>', st(r.prog));
		x.p('   <label>', 'css rule_patten: ' || x.v('<input name=rule_pat,size=100>', p_rule_pat));
		x.p('   <label>', 'rule_cnt: ' || x.v('<input name=rule_cnt>', p_rule_cnt));
		x.p('   <label>', 'dom_cnt: ' || x.v('<input name=dom_cnt>', p_dom_cnt));
		x.p('   <label>', 'nest_cnt: ' || x.v('<input name=nest_cnt>', p_nest_cnt));
		x.p('   <label>', 'wrap_cnt: ' || x.v('<input name=wrap_cnt>', p_wrap_cnt));
		x.p('   <label>', 'v_loop_cnt: ' || v_loop_cnt);
		x.p('   <label>', 'paint: ' || x.s('<input :1 type=checkbox,name=paint,value=paint>', st(x.checked(p_paint))));
		x.s('   <input type=submit>');
		x.c('  </form>');
		x.o('  <div#topmost>');
		for j in 1 .. p_wrap_cnt loop
			x.o('<div>');
		end loop;
		for i in 1 .. v_loop_cnt loop
			if mod(i, 100) = 0 then
				h.flush;
			end if;
			for j in 1 .. p_nest_cnt loop
				x.o('<p>');
			end loop;
			x.a('<a.c:1>', 'link' || i, '#', st(i));
			for j in 1 .. p_nest_cnt loop
				x.c('</p>');
			end loop;
		end loop;
		for j in 1 .. p_wrap_cnt loop
			x.c('</div>');
		end loop;
		x.c('</div>');
		x.p('  <script>',
				'
var t_now = Number(new Date());
document.getElementById("log").innerHTML = 
	"from top of HEAD: " + (t_now - t_head) + " ms<br/>" +
	"from top of BODY: " + (t_now - t_body) + " ms<br/>" + 
	"from HEAD to BODY: " + (t_body - t_head) + " ms<br/>" 
	;');
		x.c(' </body>');
		x.c('</html>');
	end;

end css_prof_b;
/
