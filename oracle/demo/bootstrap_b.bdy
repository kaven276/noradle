create or replace package body bootstrap_b is

	-- public
	procedure use_lib is
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

	procedure navs(p_type varchar2) is
	begin
		x.o('<ul.nav.nav-tabs.-nav-pills.-nav-justified>');
		x.p(' <li.:1>', x.a('<a>', 'packages', '@b.packages'), st(x.b2c(p_type = 'packages', 'active')));
		x.p(' <li.:1>', x.a('<a>', 'tables', '@b.tables'), st(x.b2c(p_type = 'tables', 'active')));
		x.o(' <li.dropdown.:1>', st(x.b2c(p_type = 'images', 'active')));
		x.a('  <a.dropdown-toggle `toggle=dropdown>', 'images ' || x.s('<span.caret>'), '@b.images');
		x.o('  <ul.dropdown-menu>');
		x.p('   <li>', x.a('<a>', '1', '@b.images?cols=1'));
		x.p('   <li>', x.a('<a>', '2', '@b.images?cols=2'));
		x.p('   <li>', x.a('<a>', '3', '@b.images?cols=3'));
		x.p('   <li>', x.a('<a>', '4', '@b.images?cols=4'));
		x.p('   <li>', x.a('<a>', '6', '@b.images?cols=6'));
		x.c('  </ul>');
		x.c(' </li>');
		x.c('</ul>');
	end;

	procedure packages is
		p_oname varchar2(100) := upper(nvl(r.getc('oname', '%'), '%'));
	begin
		use_lib;
		--x.p('<h1>', lengthb(p_oname));
		navs('packages');
	
		-- form
		x.o('<form.form-inline role=form,method=get,action=:1>', st(r.prog));
		x.o(' <div.form-group>');
		x.p('  <lable>', 'object name');
		x.s('  <input.form-control type=text,name=oname,placeholder=%>');
		x.c(' </div>');
		x.o(' <div.form-group>');
		x.s('  <input.form-control type=datetime,name=created,placeholder=created after>');
		x.c(' </div>');
		x.s(' <input.btn.btn-primary type=submit>');
		x.c('</form>');
	
		--x.o('<div.container-fluid>');
		--x.o('<div.table-responsive>');
		x.o('<table.table.table-striped.table-bordered.table-hover.table-condensed>');
		x.o(' <thead>');
		x.o('  <tr>');
		x.p('   <th>', 'object name');
		x.p('   <th>', 'create time');
		x.p('   <th>', 'operations');
		x.c('  </tr>');
		x.c(' </thead>');
		x.o(' <tbody>');
		for i in (select a.*
								from user_objects a
							 where a.object_type = 'PACKAGE'
								 and a.object_name like p_oname) loop
			x.o('<tr>');
			x.p(' <td>', i.object_name);
			x.p(' <td>', i.created);
			x.p(' <td>',
					x.a('<a.btn.btn-sm.btn-default role=button>',
							x.s('<span.glyphicon.glyphicon-eye-open>') || ' view',
							'@b.show_code?pack=' || i.object_name));
			x.c('</tr>');
		end loop;
		x.c(' </tbody>');
		x.c('</table>');
		--x.c('</div>');
		--x.c('</div>');
	end;

	procedure tables is
		p_oname varchar2(100) := upper(nvl(r.getc('oname', '%'), '%'));
	begin
		use_lib;
		navs('tables');
	
		x.o('<table.table.table-bordered>');
		x.o(' <thead>');
		x.o('  <tr>');
		x.p('   <th>', 'table name');
		x.p('   <th>', 'num-of-rows');
		x.p('   <th>', 'partition');
		x.p('   <th>', 'operations');
		x.c('  </tr>');
		x.c(' </thead>');
		x.o(' <tbody>');
		for i in (select a.* from user_tables a where a.table_name like p_oname) loop
			x.o('<tr>');
			x.p(' <td>', i.table_name);
			x.p(' <td>', i.num_rows);
			x.p(' <td>', i.partitioned);
			x.p(' <td>', x.a('<a>', ' view', '@b.table_detail?tname=' || i.table_name));
			x.c('</tr>');
		end loop;
		x.c(' </tbody>');
		x.c('</table>');
	end;

	procedure show_code is
		p_pack varchar2(32) := r.getc('pack');
		v_flag boolean := true;
	begin
		use_lib;
		x.o('<div.dropdown.pull-right style=display:inline-block;>');
		x.p(' <button.btn.btn-default.dropdown-toggle `toggle=dropdown>', 'navigate ' || x.s('<span.caret>'));
		x.o(' <ul.dropdown-menu.dropdown-menu-right>');
		x.p('  <li>', x.a('<a>', 'go spec', '#spec'));
		x.p('  <li>', x.a('<a>', 'go body', '#body'));
		x.p('  <li>', x.a('<a>', 'go end', '#end'));
		x.s('  <li.divider>');
		-- x.p('  <li>', x.a('<a>', 'go back', 'javascript:history.back()'));
		x.p('  <li>', x.a('<a>', 'go back', r.referer));
		x.c(' </ul>');
		x.c('</div>');
	
		x.o('<pre>');
		x.p('<a name=spec>', '');
		for i in (select a.* from user_source a where a.name = p_pack order by a.type asc, a.line asc) loop
			if v_flag and i.type = 'PACKAGE BODY' then
				x.t('<hr/>');
				v_flag := false;
				x.p('<a name=body>', '');
			end if;
			x.t(x.e(replace(replace(i.text, chr(10), ''), chr(9), '&nbsp;&nbsp;')));
		end loop;
		x.p('<a name=end>', '');
		x.c('</pre>');
	end;

	procedure button_toolbar is
		v_st   st := st('lg', '', 'sm', 'xs');
		v_base varchar2(100) := r.prog || '?cols=';
	begin
		x.o('<div.btn-toolbar style=margin:3px 6px;>');
		for i in 1 .. 4 loop
			x.o('<div.btn-group.btn-group-:1>', st(v_st(i)));
			x.a(' <a.btn.btn-default>', '1', v_base || '1');
			x.a(' <a.btn.btn-default>', '2', v_base || '2');
			x.a(' <a.btn.btn-default>', '3', v_base || '3');
			x.a(' <a.btn.btn-default>', '4', v_base || '4');
			x.a(' <a.btn.btn-default>', '6', v_base || '6');
			x.c('</div>');
		end loop;
		x.c('</div>');
	end;

	procedure images is
		p_cols varchar2(2) := r.getc('cols', '3');
	begin
		use_lib;
		navs('images');
		button_toolbar;
		x.o('<div.container>');
		x.o(' <div.row>');
		for i in 1 .. 24 loop
			x.p('<div.col-xs-:1>', x.i('<img.img-responsive.img-thumbnail.img-circle>', '^img/larry.jpg'), st(p_cols));
			if mod(i, 4) = 0 then
				null; --x.t('</div><div class="row">');
			end if;
		end loop;
		x.c(' </div>');
		x.c('</div>');
	end;

end bootstrap_b;
/
