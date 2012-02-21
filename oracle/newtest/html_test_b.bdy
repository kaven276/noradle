create or replace package body html_test_b is

	procedure d is
		cursor c_packages is
			select * from user_objects a where a.object_type = 'PACKAGE' order by a.object_name asc;
	begin
		h.status_line;
		h.content_type(charset => 'utf-8');
		-- h.transfer_encoding_chunked;
		-- h.content_encoding_gzip;
		h.header_close;
	
		pv.csslink := false;
		p.h;
		p.div_open(id => 'wrapper');
		p.lcss('{margin:0px;background-color:#EEE;}');
	
		p.div_open(id => 'text', ac => st('#border:1px solid silver;width:80%;padding:8px 20px;'));
		for i in 1 .. 6 loop
			p.hn(i, 'header ' || i);
			p.p('a paragraph');
		end loop;
		p.div_close;
	
		p.ul_open(id => 'ul');
		for i in c_packages loop
			p.li(i.object_name);
		end loop;
		p.ul_close;
	
		p.ol_open(id => 'ul');
		for i in c_packages loop
			p.li(i.object_name);
		end loop;
		p.ol_close;
	
		p.dl_open;
		for i in c_packages loop
			p.dt(i.object_name);
			p.dd(t.d2s(i.created));
		end loop;
		p.dl_close;
	
		p.hr;
	
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
	
		p.fieldset_open;
		p.legend('form example');
		p.form_open('f', 'action', '_blank', method => 'get');
		p.input_text('name', label_ex => 'your name');
		p.input_password('pass', label_ex => 'your password');
		p.input_submit;
		p.form_close;
		p.fieldset_close;
	
		p.div_close;
	
		for i in 1 .. r.getn('count', 0) loop
			p.p(i);
		end loop;
	end;

	procedure form is
	begin
		h.allow('GET,POST');
		h.status_line(200);
		h.header_close;
		p.init;
		p.http_header_close;
		p.h;
		p.p(r.getc('file', 'no upload file for "file"'));
		begin
			r.gets('file', tmp.stv);
			for i in 1 .. tmp.stv.count loop
				p.p(tmp.stv(i));
			end loop;
		exception
			when others then
				null;
		end;
		p.p(r.getc('file2', 'no upload file for "file2"'));
		p.fieldset_open;
		p.legend('form example');
		p.form_open('f', 'form', '_self', method => 'post', enctype => 'multipart/form-data');
		p.input_text('name', label_ex => 'your name');
		p.input_password('pass', label_ex => 'your password');
		p.input_hidden('$file', 'test/');
		p.input_file('file', ac => st('size=30;height=5;multiple=true;'));
		p.input_file('file', ac => st('size=30;height=5;multiple=true;'));
		p.input_hidden('$file2', 'test2/');
		p.input_file('file2', ac => st('size=30;height=5;multiple=true;'));
		p.input_submit;
		p.form_close;
		p.fieldset_close;
		p.html_tail;
	end;

end html_test_b;
/
