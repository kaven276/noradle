create or replace package body post_file_b is

	procedure upload_form is
	begin
		h.allow('GET,POST');
		h.status_line(200);
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

	procedure ajax_post is
	begin
		p.h;
		src_b.link_proc;
    src_b.link_pack;
		p.script_text('
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
		p.div_open(id => 'content');
		p.div_close;
	end;

	procedure echo_http_body is
		v_line  varchar2(200);
		v_nline nvarchar2(200);
	begin
		h.allow('POST');
		h.content_type('text/plain');

		case 2
			when 1 then
				p.http_header_close;
				p.line(r.method);
				p.line(r.header('content-type'));
				p.line(r.header('content-length'));
				p.line(rb.charset_http);
				p.line(rb.charset_db);
				p.line(dbms_lob.getlength(rb.blob_entity));
				r.body2clob;
				p.line(dbms_lob.getlength(rb.clob_entity));
			when 2 then
				r.body2clob;
				p.d(rb.clob_entity);
			when 3 then
				r.body2clob;
				p.h;
				r.read_line_init(chr(10));
				for i in 1 .. 5 loop
					r.read_line(v_line);
					p.line(i);
					p.line(v_line);
					exit when r.read_line_no_more;
				end loop;
			when 4 then
				r.body2nclob;
				p.h;
				r.read_line_init(chr(10));
				for i in 1 .. 5 loop
					r.read_nline(v_nline);
					p.line(i);
					p.line(v_nline);
					exit when r.read_line_no_more;
				end loop;
		end case;
	end;

end post_file_b;
/
