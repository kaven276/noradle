create or replace package body style_b is

	procedure d is
		procedure comp1(n pls_integer) is
		begin
			if r.is_null('css$comp1') then
				r.setc('css$comp1', null);
				y.lcss_ctx('ul#comp1');
				y.lcss_selector(' ');
				y.lcss_rule('font-size:20px;');
				y.lcss_rule('border:1px solid;');
				y.lcss_rule('width:300px;');
				y.lcss_rule('width:300px;');
				y.lcss_rule('padding:16px;', true);
				y.lcss('{^border-radius:16px;}', true);
				y.lcss('li{list-style:inside url(^GER.gif);}');
				y.lcss('>li:nth-child(2n){color:orange;}');
				y.lcss('>li:nth-child(2n+1){color:yellow;}');
			end if;
			x.p('<p>', 'list ' || n);
			x.o('<ul#comp1>');
			for i in 1 .. 10 loop
				x.p(' <li>', to_char(i));
			end loop;
			x.c('</ul>');
		end;
	begin
		x.o('<html>');
		x.o('<head>');
		x.p('<title>', 'use style(sty) API to procedure css embeded or linked');
		y.set_scale(320, 480);
		y.set_css_prefix('-webkit-');
		-- all css content or css url will be here.
		y.embed(r.getc('tag', '<style>'));
		x.c('</head>');
		x.o('<body>');
		src_b.link_proc;
		y.prn('body{background-color:green;}' || chr(10));
		x.p('<p>', 'look at the ul list, they use the following features');
		x.o('<ol>');
		x.p(' <li>', 'scaling');
		x.p(' <li>', 'url reference');
		x.p(' <li>', 'vendor prefix');
		x.p(' <li>', 'repeating css prevention');
		x.c('</ol>');
		comp1(1);
		comp1(2);
		x.c('</body>');
		x.c('</html>');
	end;

end style_b;
/
