create or replace package body po_content_b is

	procedure packages is
	begin
		x.o('<html>');
		x.o(' <body>');
		for i in (select a.*
								from user_objects a
							 where a.object_type = 'PACKAGE'
								 and a.object_name like '%_B') loop
			x.p('<p>', x.a('<a>', i.object_name, '@b.procedures?pack=' || i.object_name));
		end loop;
		x.c(' </body>');
		x.c('</html>');
	end;

	procedure procedures is
		p_pack varchar2(30) := r.getc('pack');
	begin
		x.o('<html>');
		x.o(' <body>');
		for i in (select a.*
								from user_procedures a
							 where a.object_name = p_pack
								 and a.procedure_name is not null) loop
			x.o('<p>');
			x.p(' <b>', i.procedure_name);
			x.a(' <a>', 'src', 'src_b.proc?p=' || p_pack || '.' || i.procedure_name);
			x.a(' <a>', 'exec', lower(p_pack || '.' || i.procedure_name));
			x.c('</p>');
		end loop;
		x.c(' </body>');
		x.c('</html>');
	end;

end po_content_b;
/
