create or replace package body upload_b is

	procedure upload_form is
	begin
		h.allow('GET,POST');
		h.header_close;

		p.h;
		p.p('file: ' || r.getc('file', 'no upload file for "file"'));
		begin
			r.gets('file', tmp.stv);
			for i in 1 .. tmp.stv.count loop
				p.p('file[]: ' || tmp.stv(i));
			end loop;
		exception
			when others then
				null;
		end;
		p.p('file2: ' || r.getc('file2', 'no upload file for "file2"'));
		p.p('file3: ' || r.getc('file3', 'no upload file for "file3"'));
		p.fieldset_open;
		p.legend('form example');
		p.form_open('f', 'upload_form', '_self', method => 'post', enctype => 'multipart/form-data');
		p.input_text('name', label_ex => 'your name');
		p.input_password('pass', label_ex => 'your password');
		p.br;
		p.input_hidden('_file', 'test/');
		p.input_file('file', ac => st('size=30;height=5;multiple=true;'));
		p.input_file('file', ac => st('size=30;height=5;multiple=true;'));
		p.br;
		p.input_hidden('_file2', 'test2/specified.');
		p.input_file('file2', ac => st('size=30;height=5;multiple=true;'));
		p.br;
		p.input_file('file3', ac => st('size=30;height=5;multiple=true;'));
		p.br;
		p.input_submit;
		p.form_close;
		p.fieldset_close;
	end;

end upload_b;
/
