create or replace package body basic_io_b is

	procedure req_info is
		n  varchar2(100);
		v  varchar2(999);
		va st;
	begin
		h.set_line_break(chr(10));
		src_b.link_proc;
		h.line('<pre>');
	
		h.line('[ This is the basic request info derived from http request line and host http header ]');
		h.line('r.method : ' || r.method);
		h.line('r.url : ' || r.url);
		h.line('r.base : ' || r.base);
		h.line('r.dad : ' || r.dad);
		h.line('r.prog : ' || r.prog);
		h.line('r.pack : ' || r.pack);
		h.line('r.proc : ' || r.proc);
		h.line('r.path : ' || r.path);
		h.line('r.qstr : ' || r.qstr);
		h.line('r.host : ' || r.host);
		h.line('r.host_prefix : ' || r.host_prefix);
		h.line('r.port : ' || r.port);
		h.line('r.url_full : ' || r.url_full);
	
		h.line;
		h.line('[ This is the basic request info derived from http header ]');
		h.line('r.ua : ' || r.ua);
		h.line('r.referer : ' || r.referer);
		h.line('r.bsid : ' || r.bsid);
		h.line('r.msid : ' || r.msid);
	
		h.line;
		h.line('[ This is about client address]');
		h.line('r.client_addr : ' || r.client_addr);
		h.line('r.client_port : ' || r.client_port);
	
		h.line;
		h.line('[ This is all original http request headers ]');
		n := ra.headers.first;
		loop
			exit when n is null;
			v := ra.headers(n);
			h.line(n || ' : ' || v);
			n := ra.headers.next(n);
		end loop;
	
		h.line;
		h.line('[ This is all http request cookies ]');
		n := ra.cookies.first;
		loop
			exit when n is null;
			v := ra.cookies(n);
			h.line(n || ' : ' || v);
			n := ra.cookies.next(n);
		end loop;
	
		h.line;
		h.line('[ This is all http request parameter that may be got from the following ways ]');
		h.line('query string, post with application/x-www-form-urlencoded, post with multipart/form-data');
		n := ra.params.first;
		loop
			exit when n is null;
			va := ra.params(n);
			h.line(n || ' : ' || t.join(va, ','));
			n := ra.params.next(n);
		end loop;
	
		p.line('</pre>');
	end;

	procedure output is
	begin
		h.set_line_break(chr(10));
		src_b.link_proc;
		h.line('<pre>');
	
		h.line('Basic output include the following APIs');
		h.line('h.write(text) : write text to http entity content');
		h.line('h.writeln(text) : write text and newline character(s) to http entity content');
		h.line('h.string(text) : write text to http entity content');
		h.line('h.line(text) : write text and newline character(s) to http entity content');
		h.line('h.set_line_break(nlbr) : set the newline break character(s), usually LF,CR,CRLF');
	
		h.line;
		h.write('output by h.write');
		h.writeln('output by h.writeln');
		h.string('output by h.string');
		h.line('output by h.line');
	
		h.line;
		h.line('h.write = h.string, they are just alias each other');
		h.line('h.writeln = h.line, they are just alias each other');
	
		h.line;
		h.line('line break can be set using h.set_line_break()');
		h.set_line_break(chr(10));
		h.line('This is line end with line break chr(10) or LF');
		h.set_line_break(chr(13));
		h.line('This is line end with line break chr(13) or CR');
		h.set_line_break(chr(13) || chr(10));
		h.line('This is line end with line break chr(13)||chr(10) or CRLF');
		h.line('</pre>');
	end;

	procedure parameters is
	begin
		p.h;
		src_b.link_proc;
		p.br;
	
		p.form_open('f', 'req_info?qstr1=A&qstr1=B&p1=0', method => 'get');
		p.select_open('mtd');
		p.select_option('get');
		p.select_option('post');
		p.select_close;
		p.script_text('document.f.mtd.onchange=function(){document.f.method = this.value;};');
		p.input_text('p1', '1');
		p.input_text('p1', '2');
		p.input_submit;
		p.form_close;
	
		p.br;
		p.p('Method get will erase the query string in form.action.');
		p.p('Method post will keep the query string in form.action but replace the parameter in qstr if there are same named form items.');
	
	end;

	procedure any_size is
		v_size  number(8) := r.getn('size', 0);
		v_chunk varchar2(1024) := rpad('H', 1024, '.');
	begin
		k_debug.set_run_comment('size:' || v_size);
		for i in 1 .. v_size loop
			h.write(v_chunk);
		end loop;
	end;

end basic_io_b;
/
