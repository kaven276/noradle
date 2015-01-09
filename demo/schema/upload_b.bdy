create or replace package body upload_b is

	procedure upload_form is
	begin
		h.allow('GET,POST');
		h.header_close;
	
		pc.h;
		x.p('<p>', 'file: ' || r.getc('file', 'no upload file for "file"'));
		begin
			r.gets('file', tmp.stv);
			for i in 1 .. tmp.stv.count loop
				x.p('<p>', 'file[]: ' || tmp.stv(i));
			end loop;
		exception
			when others then
				null;
		end;
		x.p('<p>', 'file2: ' || r.getc('file2', 'no upload file for "file2"'));
		x.p('<p>', 'file3: ' || r.getc('file3', 'no upload file for "file3"'));
		x.o('<fieldset>');
		x.p(' <legend>', 'form example');
		x.o(' <form name=f,action=upload_b.upload_form,target=_self,method=post,enctype=multipart/form-data>');
	
		x.p('  <label>', 'your name' || x.v('<input type=text,name=name>', r.getc('name')));
		x.p('  <label>', 'your password' || x.v('<input type=password,name=pass>', r.getc('pass')));
	
		x.t('  <br/>');
		x.s('  <input type=hidden,name=_file,value=test/>');
		x.s('  <input type=file,name=file,size=30;height=5;multiple=true>');
		x.s('  <input type=file,name=file,size=30;height=5;multiple=true>');
		x.t('  <br/>');
	
		x.s('  <input type=hidden,name=_file2,value=test2/specified>');
		x.s('  <input type=file,name=file2,size=30;height=5;multiple=true>');
		x.t('  <br/>');
	
		x.s('  <input type=file,name=file3,size=30;height=5;multiple=true>');
		x.t('  <br/>');
	
		x.s(' <input type=submit>');
		x.c(' </form>');
		x.c('</fieldset>');
	end;

end upload_b;
/
