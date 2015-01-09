create or replace package body pg_test_b is

	procedure use_tag is
	begin
		x.o('<html>');
		x.o('<body>');
		src_b.link_proc;
		x.p('<p>', x.e('basic tag <p> --- <p>'));
		x.p('<p#id1>', x.e('use "#" to set element id, <p#id1> --- <p id="id1">'));
		x.p('<p.c1>', x.e('use "." to set one element class, <tag.c1> --- <p class="c1">'));
		x.p('<p.c1.c2>', x.e('use more "." to set classes, <p.c1.c2> --- <p class="c1 c2">'));
		x.p('<p title=demo>', x.e('after a space set attr without quotes "..." <p title=demo> --- <p title="demo">'));
		x.p('<p a1=v1,a2=v2>', x.e('set multiple attrs seperated by comma , <p a1=v1,a2=v2> -- <p a1="v1",a2="v2">'));
		x.p('<p#id1.c1.c2 a1=v1,a2=v2>',
				x.e('all together, id class attr by order, <p#id1.c1.c2 a1=v1,a2=v2> --- <p id="id1" class="c1 c2" a1="v1" a2="v2">'));
	
		x.p('<p#:1.:2.c:3 :4 :5 a1=:6,a2=head-:7-tail>',
				x.e('dynamic bind anywhere <p#:1.:2.c:3 :4 :5 a1=:6,a2=head-:7-tail>,...,st(''id1'', ''c1'', ''2'', ''checked'', ''disabled'', ''v1'', ''body'') 
				<p id="id1" class="c1 c2" checked disabled a1="v1" a2="head-body-tail">...</p>'),
				st('id1', 'c1', '2', 'checked', 'disabled', 'v1', 'body'));
	
		x.o('<div#id1.c1.c2 a1=v1,a2=v2>');
		x.p(' <div#id2.c1.c2 a1=v1,a2=v2>', 'x.wrp tag#id');
		x.p(' <#id3.c1.c2 a1=v1,a2=v2>', 'x.wrp #id');
		x.p(' <span.c1.c2 a1=v1>', 'text2, next API call will be cut');
		x.p(' <span.c1.c2 a1=v1>', 'text2', cut => true);
		x.p(' <span.c1.c2 a1=v1,a2=v2>', '');
		x.p(' <span.:1 title=:2>', 'a paragraph', st('state1', 'title info'));
	
		x.o(' <ul#list>');
		for i in 1 .. 10 loop
			x.p('<li>', 'item ' || i);
		end loop;
		x.c(' </ul>');
	
		x.c('</div>');
	
		if false then
			x.o('<table rules=all>');
			for i in (select * from user_tables a) loop
				x.o('<tr>');
				x.p(' <td>', i.table_name);
				x.p(' <td>', i.cluster_name);
				x.p(' <td>', i.iot_name);
				x.c('</tr>');
			end loop;
			x.c('</table>');
		end if;
	
		x.o('<#id.c1.c2 a1=v1,style=margin:1em;>');
		x.t(' I am in div');
		x.t(' I am in :1', st('div too'));
		x.t('I am been cut', cut => true);
		x.p('<>', 'nested div');
		x.c('</div>');
	
		x.o('<span.c1.c2 a1=v1,a2=v2>');
		x.t(' inline text', null, true);
		x.c('</span>');
	
		x.p('<h1>', 'empty content tags');
		x.p('<script#id.c1.c2 src=/a.js,defer=true>', '');
		x.p('<iframe src=a.html>', '');
		x.p('<a href=:1>', 'a link', st('./a.html'));
	
		x.p('<h1>', 'self closed tags');
		x.s('<link href=/a.css,rel=stylesheet>');
		x.s('<img#id.c1.c2 width=100,height=100>');
		x.t('<br/>');
		x.s('<input :1 :2 type=text,name=pname,value=liyong>', st(x.checked(true), x.disabled(true)));
	
		x.o('<table rules=all,style=border:1px solid red;width:80%;>');
		x.p('<style>', 'td{border:1px solid gray;padding:3px;}');
		x.p('<caption>', 'table test');
		for i in 1 .. 5 loop
			x.o('<tr>');
			for j in 1 .. 5 loop
				x.p('<td>', j);
			end loop;
			x.c('</tr>');
		end loop;
		x.c('</table>');
	end;

	procedure odd_even_switch is
		v_classes st := st('one', 'two', 'three');
	begin
		x.o('<html>');
		x.o('<body>');
		src_b.link_proc;
	
		x.p('<style>', '.one{color:red}.two{color:blue}.three{color:green}');
		x.p('<style>', '.c0,.even{color:red}.c1,.odd{color:green}');
	
		tmp.i := 0;
		x.o('<ul>');
		for i in 1 .. 10 loop
			x.p('<li.:1>', i, st('c' || to_char(tmp.i)));
			tmp.i := 1 - tmp.i;
		end loop;
		x.c('</ul>');
	
		x.o('<ol>');
		for i in 1 .. 10 loop
			x.p('<li.:1>', i, st('c' || to_char(mod(i, 2))));
		end loop;
		x.c('</ol>');
	
		x.o('<ol>');
		for i in 1 .. 10 loop
			x.p('<li.:1>', i, st(v_classes(1 + mod(i - 1, 3))));
		end loop;
		x.c('</ol>');
	
		tmp.b := true;
		x.o('<table>');
		for i in 1 .. 10 loop
			x.p('<tr.:1>', x.p('<td>', i), st(t.tf(tmp.b, 'odd', 'even')));
			tmp.b := not tmp.b;
		end loop;
		x.c('</table>');
	end;

	procedure multi is
		v sys_refcursor;
	begin
		x.o('<html>');
		x.o('<body>');
		src_b.link_proc;
		x.p('<style>', 'fieldset{margin 3em 2em;padding:0.5ex;margin-bottom:3em;}');
		x.p('<style>', 'legend{margin-top: 3em;padding:0.5ex;}');
		x.p('<style>', 'em{font:bold;}');
		x.p('<style>', '#letters>b:nth-child(2n){color:green;}');
		x.p('<style>', '#letters>b:nth-child(2n+1){color:red;}');
	
		x.p('<div#letters>', x.w('Noradle') || ' is easy coding web tech!');
	
		open v for
			select a.object_name, a.object_type from user_objects a where rownum < 10;
		x.o('<fieldset>');
		x.p(' <legend>', 'sys_refcursor to simple fill ul list');
		x.o(' <ul>');
		m.c('  <li><b>@</b><small> - (@)</small></li>', v);
		x.c(' </ul>');
		x.c('</fieldset>');
	
		open v for
			select rownum rid, a.object_name, a.object_type from user_objects a where rownum < 10;
		x.o('<fieldset>');
		x.p(' <legend>', 'sys_refcursor to simple fill table rows');
		x.o(' <table rules=all>');
		m.c('  <tr><td>@</td><td>@</td><td><input name="a" type="text" value="@"/></td></tr>', v);
		x.c(' </table>');
		x.c('</fieldset>');
	
		open v for
			select rownum rid, a.object_name, a.object_type from user_objects a where rownum < 10;
		x.o('<fieldset>');
		x.p(' <legend>', 'm.tpl_cur support sys_refcursor, SQL itself do col order/format, high preformance');
		m.c('  @ - <label><input name="a" type="checkbox" value="@"/>@</label><br/>', v);
		x.c('</fieldset>');
	
		x.o('<fieldset>');
		x.p(' <legend>', 'traditional x.t, support col order/format, but has <em>bad</em> preformance');
		for i in (select rownum rid, a.object_name, a.object_type from user_objects a where rownum < 10) loop
			tmp.stv := st(to_char(i.rid, '09'), i.object_name, i.object_type);
			x.t(' :1 - <label><input name="a" type="checkbox" value=":3"/>:2</label><br/>', tmp.stv);
		end loop;
		x.c('</fieldset>');
	
		x.o('<fieldset>');
		x.p(' <legend>', 'm.w, support col order/format, but has <em>bad</em> preformance');
		x.o(' <table rules=all>');
		x.p('  <thead>', x.p('<tr>', m.w('<th>@</th>', 'order,object_name,object_type')));
		for i in (select rownum rid, a.object_name, a.object_type from user_objects a where rownum < 10) loop
			tmp.stv := st(ltrim(to_char(i.rid, '09')), i.object_name, i.object_type);
			-- better performance vs better code readability
			x.p('<tr>', m.w('<td>', tmp.stv, '</td>'));
			x.p('<tr>', m.w('<td><input type="text" value="@"/></td>', tmp.stv));
		end loop;
		x.c(' </table>');
		x.c('</fieldset>');
	
		x.o('<fieldset>');
		x.p(' <legend>', 'm.parse once, m.render repeatly, support col order/format, and high proformance');
		m.p('  @ - <label><input name="a" type="checkbox" value="@"/>@</label><br/>', tmp.stv);
		for i in (select rownum rid, a.object_name, a.object_type from user_objects a where rownum < 10) loop
			m.r(tmp.stv, st(to_char(i.rid, '09'), i.object_type, i.object_name));
		end loop;
		x.c('</fieldset>');
	
		m.w('<col class="@"/>', 'col1,col2,col3');
	end;

	procedure tree is
	begin
		x.o('<html>');
		x.o('<body>');
		src_b.link_proc;
		x.p('<h2>', 'use m.p, m.ro, m.r(in for SQL loop), m.rc to print tree');
	
		x.o('<ul>');
		m.p(' <li class="xing-@"><a href="see?pid=@">@</a>|</li>', '<ul>', tmp.stv);
		m.ro(true);
		for i in (select level, a.* from emp_t a start with a.name = 'Li Xinyan' connect by a.ppid = prior a.pid) loop
			m.r(tmp.stv, i.level, st(substr(i.name, 1, 1), i.pid, i.name));
		end loop;
		m.rc(tmp.stv);
	
		m.p(' <li class="xing-@"><b>@</b>|</li>', '<ul>', tmp.stv);
		m.ro(pretty => true);
		for i in (select level, a.* from emp_t a start with a.name = 'Li Xinyan' connect by a.ppid = prior a.pid) loop
			m.r(tmp.stv, i.level, st(substr(i.name, 1, 1), i.name));
		end loop;
		m.rc(tmp.stv);
		x.c('</ul>');
	end;

	procedure form is
		cur sys_refcursor;
		sv  varchar2(4000) := r.getc('sv', '');
	begin
		x.o('<html>');
		x.o('<body>');
		src_b.link_proc;
	
		open cur for
			select a.object_id, a.object_name from user_objects a where rownum < 10;
		x.o('<select multiple name=select,size=6>');
		m.w(' <option ?selected value="@"/>@</option>', cur, sv);
		x.c('</select>');
		x.t('<br/>');
	
		open cur for
			select a.object_id, a.object_name from user_objects a where rownum < 10;
		x.p('<select name=select>', m.w('<option ?selected value="@"/>@</option>', cur, sv));
		x.t('<br/>');
	
		open cur for
			select a.object_id, a.object_name from user_objects a where rownum < 10;
		x.o('<fieldset>');
		x.p(' <legend>', 'radio groups');
		m.w(' <label><input ?checked type="radio" name="single" value="@"/>@</label><br/>', cur, sv);
		x.c('</fieldset>');
	
		open cur for
			select a.object_id, a.object_name from user_objects a where rownum < 10;
		x.o('<fieldset>');
		x.p(' <legend>', 'checkbox groups');
		m.w(' <label><input ?checked type="checkbox" name="single" value="@"/>@</label><br/>', cur, sv);
		x.c('</fieldset>');
	end;

end pg_test_b;
/
