create or replace package body post_file_b is

	procedure upload_form is
	begin
		h.allow('GET,POST');
		h.status_line(200);
		h.header_close;
	
		pc.h;
		src_b.link_proc;
		x.p('<p>', 'use form item with name as "_name" to set "name" file upload save dir(relative to upload root)');
		x.p('<p>', 'file: ' || r.getc('file', 'no upload file for "file"'));
		begin
			r.gets('file', tmp.stv);
			tmp.cnt := r.cnt('file');
			for i in 1 .. tmp.cnt loop
				x.p('<p>', 'file[' || i || ']: ' || tmp.stv(i) || ', size ' || r.getc('file.size', 0, i));
			end loop;
		exception
			when others then
				null;
		end;
		x.p('<p>', 'file2: ' || r.getc('file2', 'no upload file for "file2"') || ', size ' || r.getc('file2.size', 0));
		x.p('<p>', 'file3: ' || r.getc('file3', 'no upload file for "file3"') || ', size ' || r.getc('file3.size', 0));
		x.o('<fieldset>');
		x.p(' <legend>', 'form example');
		x.o(' <form name=f,action=post_file_b.upload_form,target=_self,method=post,enctype=multipart/form-data>');
		x.p('  <label>', 'your name' || x.v('<input type=text,name=name>', r.getc('name')));
		x.p('  <label>', 'your password' || x.v('<input type=password,name=pass>', r.getc('pass')));
		x.t('  <br/>');
		x.s('  <input type=hidden,name=_file,value=test/>');
		x.s('  <input type=file,name=file,size=30,height=5,multiple=true>');
		x.s('  <input type=file,name=file,size=30,height=5,multiple=true>');
		x.t('  <br/>');
		x.s('  <input type=hidden,name=_file2,value=test2/specified/>');
		x.s('  <input type=file,name=file2,size=30,height=5,multiple=true>');
		x.t('  <br/>');
		x.s('  <input type=file,name=file3,size=30,height=5,multiple=true>');
		x.t('  <br/>');
		x.s('  <input type=submit>');
		x.c('</form>');
		x.c('</fieldset>');
	end;

	procedure ajax_post is
	begin
		pc.h;
		src_b.link_proc;
		src_b.link_pack;
		x.p('<script>',
				'
var xhr = new XMLHttpRequest();
xhr.open("POST","post_file_b.echo_http_body");
xhr.onreadystatechange = function() {
	if(xhr.readyState != 4 ) return;
	if(xhr.status != 200) return;
	document.getElementById("content").innerHTML = xhr.responseText;
}
xhr.send("<p>abedefg</p>\n\
<p>hijklmn</p>\n\
<p>opq rst</p>\n\
<p>uvw xyz</p>");
');
		x.p('<div#content>', '');
	end;

	procedure echo_http_body is
		v_line  varchar2(200);
		v_nline nvarchar2(200);
	begin
		h.allow('POST');
		h.content_type('text/plain');
	
		case 2
			when 1 then
				h.line(r.method);
				h.line(r.header('content-type'));
				h.line(r.header('content-length'));
				h.line(rb.charset_http);
				h.line(rb.charset_db);
				h.line(dbms_lob.getlength(rb.blob_entity));
				r.body2clob;
				h.line(dbms_lob.getlength(rb.clob_entity));
			when 2 then
				r.body2clob;
				h.write(rb.clob_entity);
			when 3 then
				r.body2clob;
				pc.h;
				r.read_line_init(chr(10));
				for i in 1 .. 5 loop
					r.read_line(v_line);
					h.line(i);
					h.line(v_line);
					exit when r.read_line_no_more;
				end loop;
			when 4 then
				r.body2nclob;
				pc.h;
				r.read_line_init(chr(10));
				for i in 1 .. 5 loop
					r.read_nline(v_nline);
					h.line(i);
					h.line(v_nline);
					exit when r.read_line_no_more;
				end loop;
		end case;
	end;

end post_file_b;
/
