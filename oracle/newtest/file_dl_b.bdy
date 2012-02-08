create or replace package body file_dl_b is

	procedure d is
	begin
		h.http_header_close;
		p.init;
		p.h;
		p.style_open;
		p.line('a{display:block;line-height:2em;}');
		p.style_close;
		p.a('download text', 'text');
		p.a('download excel', 'excel');
		p.a('download word', 'word');
	end;

	procedure text is
	begin
		h.status_line;
		h.content_type('text/plain', charset => 'utf-8');
		h.content_disposition_attachment('test.txt');
		h.http_header_close;
		p.line('some text');
		p.line('some other text');
	end;

	procedure excel is
		cursor c_packages is
			select * from user_objects a where a.object_type = 'PACKAGE' order by a.object_name asc;
	begin
		h.status_line;
		h.content_type('text/html', charset => 'utf-8');
		h.content_disposition_attachment('test.xls');
		h.http_header_close;
	
		p.init;
		p.doc_type('5');
		p.h;
	
		p.table_open(rules => 'all', cellspacing => 0, cellpadding => 5, ac => st('#border:1px solid silver;'));
		p.caption('table example');
		p.thead_open;
		p.tr(p.ths(st('package name', 'created')));
		p.thead_close;
		p.tbody_open;
		for i in c_packages loop
			p.tr_open;
			p.td(i.object_name);
			p.td(t.d2s(i.created));
			p.tr_close;
		end loop;
		p.tbody_close;
		p.table_close;
	end;

	procedure word is
	begin
		h.status_line;
		h.content_type('text/html', charset => 'utf-8');
		h.content_disposition_attachment('test.doc');
		h.http_header_close;
	
		p.init;
		p.doc_type('5');
		p.h;
	
		p.div_open(id => 'text', ac => st('#border:1px solid silver;width:80%;padding:8px 20px;'));
		for i in 1 .. 6 loop
			p.hn(i, 'header ' || i);
			p.p('a paragraph');
		end loop;
		p.div_close;
	
	end;

end file_dl_b;
/
