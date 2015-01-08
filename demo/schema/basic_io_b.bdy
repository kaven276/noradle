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
		h.line('r.url_full : ' || r.url_full);
		h.line('r.dir_full : ' || r.dir_full);
		h.line('r.method : ' || r.method);
		h.line('r.protocol : ' || r.protocol);
		h.line('r.site : ' || r.site);
		h.line('r.host : ' || r.host);
		h.line('r.hostname : ' || r.hostname);
		h.line('r.sdns : ' || r.sdns);
		h.line('r.pdns : ' || r.pdns);
		h.line('r.port : ' || r.port);
		h.line('r.url : ' || r.url);
		h.line('r.pathname : ' || r.pathname);
		h.line('r.dir : ' || r.dir);
		h.line('r.prog : ' || r.prog);
		h.line('r.pack : ' || r.pack);
		h.line('r.proc : ' || r.proc);
		h.line('r.subpath : ' || r.subpath);
		h.line('r.qstr : ' || r.qstr);
	
		h.line;
		h.line('[ This is the basic request info derived from http header ]');
		h.line('r.ua : ' || r.ua);
		h.line('r.referer : ' || r.referer);
		h.line('r.bsid : ' || r.bsid);
		h.line('r.msid : ' || r.msid);
	
		h.line;
		h.line('[ This is about client/server address]');
		h.line('r.client_addr : ' || r.client_addr);
		h.line('r.client_port : ' || r.client_port);
		h.line('r.server_family : ' || r.server_family);
		h.line('r.server_addr : ' || r.server_addr);
		h.line('r.server_port : ' || r.server_port);
	
		h.line;
		h.line('[ This is all original http request headers exclude cookies]');
		n := ra.params.first;
		loop
			exit when n is null;
			if n like 'h$%' then
				v := ra.params(n) (1);
				h.line(n || ' : ' || v);
			end if;
			n := ra.params.next(n);
		end loop;
	
		h.line;
		h.line('[ This is all http request cookies ]');
		n := ra.params.first;
		loop
			exit when n is null;
			if n like 'c$%' then
				v := ra.params(n) (1);
				h.line(n || ' : ' || v);
			end if;
			n := ra.params.next(n);
		end loop;
	
		h.line;
		h.line('[ This is all http request parameter that may be got from the following ways ]');
		h.line('query string, post with application/x-www-form-urlencoded, post with multipart/form-data');
		h.line;
		n := ra.params.first;
		loop
			exit when n is null;
			if lengthb(n) < 2 or substrb(n, 2, 1) != '$' then
				va := ra.params(n);
				h.line(n || ' : ' || t.join(va, ', '));
				for i in 1 .. va.count loop
					h.line(r.unescape(va(i)));
				end loop;
			end if;
			n := ra.params.next(n);
		end loop;
	
		h.line;
		h.line('[ This is all request name-value pairs ]');
		h.line;
		n := ra.params.first;
		loop
			exit when n is null;
			va := ra.params(n);
			h.line(n || ' : ' || t.join(va, ', '));
			n := ra.params.next(n);
		end loop;
	
		h.line('</pre>');
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
		pc.h;
		src_b.link_proc;
		x.t('<br/>');
		x.o('<form name=f,method=get,action=:1>', st(l('@b.req_info?qstr1=A&qstr1=B&p1=0')));
		x.o(' <select name=mtd>');
		x.p('  <option>', 'get');
		x.p('  <option>', 'post');
		x.c(' </select>');
		x.p(' <script>', 'document.f.mtd.onchange=function(){document.f.method = this.value;};');
		x.s(' <input type=text,name=p1,value=1>');
		x.s(' <input type=text,name=p1,value=2>');
		x.s(' <input type=submit>');
		x.c('</form>');
		x.t('<br/>');
		x.p('<p>', 'Method get will erase the query string in form.action.');
		x.p('<p>',
				'Method post will keep the query string in form.action but replace the parameter in qstr if there are same named form items.');
	end;

	procedure keep_urlencoded is
	begin
		pc.h;
		src_b.link_proc;
		x.t('<br/>');
		x.o('<form name=f,method=get,action=:1>', st(l('@b.req_info')));
		x.o(' <select name=mtd>');
		x.p('  <option>', 'get');
		x.p('  <option>', 'post');
		x.c(' </select>');
		x.p(' <script>', 'document.f.mtd.onchange=function(){document.f.method = this.value;};');
		x.v(' <input type=text,name=_qstr1>', nvl(r.qstr, 'a=1&b=2'));
		x.v(' <input type=text,name=_qstr2>', nvl(r.qstr, 'a=3&b=4'));
		x.s(' <input type=text,name=p1,value=1>');
		x.s(' <input type=text,name=p1,value=2>');
		x.s(' <input type=submit>');
		x.c('</form>');
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
