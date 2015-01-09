create or replace package body file_dl_b is

	procedure d is
	begin
		pc.h;
		x.p('<style>', 'a{display:block;line-height:2em;}');
		src_b.link_pack;
		x.p('<p>', 'use h.content_disposition_attachment(file.ext) to download a pre-named file');
		x.a('<a>', 'download text', '@b.text');
		x.a('<a>', 'download excel', '@b.excel');
		x.a('<a>', 'download word', '@b.word');
	end;

	procedure text is
	begin
		h.set_line_break(chr(13) || chr(10));
		h.content_disposition_attachment('test.txt');
		h.line('some text');
		h.line('some other text');
	end;

	procedure excel is
		cursor c_packages is
			select * from user_objects a where a.object_type = 'PACKAGE' order by a.object_name asc;
	begin
		h.content_disposition_attachment('test.xls');
		pc.h;
	
		x.o('<table rules=all,cellspacing=0,cellpadding=5,style=border:1px solid silver;>');
		x.p('<caption>', 'table example');
		x.p(' <thead>', x.p('<tr>', m.w('<th>@</th>', 'package name,created')));
		x.o(' <tbody>');
		for i in c_packages loop
			x.p('<tr>', m.w('<td>', st(i.object_name, t.d2s(i.created)), '</td>'));
		end loop;
		x.c(' </tbody>');
		x.c('</table>');
	end;

	procedure word is
	begin
		h.content_disposition_attachment('test.doc');
		pc.h;
	
		x.o('<div#text style=border:1px solid silver;width:80%;padding:8px 20px;>');
		for i in 1 .. 6 loop
			x.p('<h' || i || '>', 'header ' || i);
			x.p('<p>', 'a paragraph');
		end loop;
		x.c('</div>');
	
	end;

end file_dl_b;
/
