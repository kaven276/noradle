create or replace package body list_b is

	procedure user_objects is
	begin
		x.o('<html>');
		x.o('<head>');
		sty.embed('<style>');
		x.c('</head>');
		x.o('<body>');
		src_b.link_proc;
		tl.cfg_init('table');
		tl.cfg_add('oname', 'obj_name', 'left', '360px');
		tl.cfg_add('otype', 'obj_type', 'left', '200px');
		sty.css('table{border:1px solid;}th,td{padding:8px;}');
		x.o('<table rules=all>');
		x.p(' <caption>', 'table list format API example');
		tl.cfg_cols_thead;
		for i in (select *
								from user_objects a
							 where a.object_name not like 'BIN$%'
								 and a.object_type not like '%PARTITION'
							 order by a.object_type, a.object_name) loop
			x.p('<tr>', m.w('<td>', st(i.object_name, i.object_type), '</td>'));
		end loop;
		x.c('</table>');
	end;

	procedure user_procedures is
		c sys_refcursor;
	begin
		x.o('<html>');
		x.o('<head>');
		sty.embed('<style>');
		x.c('</head>');
		x.o('<body>');
		src_b.link_proc;
	
		tl.cfg_init('table');
		tl.cfg_add('pack', 'package', null, '30ex');
		tl.cfg_add('proc', 'procedure');
		tl.cfg_add('objid', 'objid');
		sty.css('table{border:1px solid;}th,td{padding:8px;}');
		open c for
			select a.object_name, a.procedure_name, a.object_id from user_procedures a order by a.object_type, a.object_name;
	
		x.o('<table rules=all>');
		x.p(' <caption>', 'table list for sys_refcursor example');
		tl.cfg_content(c);
		x.c('</table>');
	end;

end list_b;
/
