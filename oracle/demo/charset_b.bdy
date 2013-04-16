create or replace package body charset_b is

	procedure form is
		v_src varchar2(200) := 'E3818DCEA609D8A6D985D8B9D8AAD8AFD984E184ACE1B4ABE1BC8EE3818EE3839E';
		v_str nvarchar2(100) := utl_i18n.raw_to_nchar(hextoraw(v_src), 'AL32UTF8');
		v_raw raw(4000);
		vc    varchar2(100);
		nvc   nvarchar2(100);
	begin
	
		v_str := utl_i18n.raw_to_nchar(hextoraw(v_src), 'AL32UTF8');
	
		-- h.content_type(charset => 'GBK');
		h.allow_get_post;
		h.header_close;
		p.h(n, v_str);
		src_b.link_proc;
		p.br;
		-- p.h('http://code.jquery.com/jquery-1.7.1.min.js');
	
		p.style_open;
		p.line('div { border:1px dotted gray;margin:1em;padding:1em;}');
		p.style_close;
	
		p.hn(3, 'basic output API for nvarchar2');
		p.div_open;
		p.prn('h.write : ');
		h.write(v_str);
		p.br;
		p.prn('h.writeln : ');
		h.writeln(v_str);
		p.br;
		p.prn('h.string : ');
		h.string(v_str);
		p.br;
		p.prn('h.line : ');
		h.line(v_str);
		p.br;
		p.prn('p.d : ');
		p.d(v_str);
		p.br;
		p.prn('p.prn : ');
		p.prn(v_str);
		p.br;
		p.prn('p.line : ');
		p.line(v_str);
		p.div_close;
	
		p.hn(3, 'other tag API using nvarchar2');
		p.div_open;
		p.prn('p.li : ');
		p.li(v_str);
		p.prn('p.caption : ');
		p.caption(v_str);
		p.div_close;
	
		p.hn(3, 'function tag API using nvarchar2');
		p.div_open;
		p.prn('p.p(p.span()) using function API: ');
		p.p(p.span(v_str));
		p.prn('p.p(p.a()) using function API: ');
		p.p(p.a(v_str, 'form?a=空降翻看'));
		p.div_close;
	
		p.br;
		p.p(utl_raw.cast_to_raw(substr(v_str, 1, 1)));
		--p.p(utl_raw.cast_to_raw(convert(substr(v_str, 1, 1), 'AL32UTF8')));
	
		-- r.req_charset_utf8;
		p.hn(3, 'request parameters');
		p.div_open;
		p.p(n'url = ' || r.getc('url', 'null'));
		p.p(n'ch = ' || r.getc('ch', 'null'));
		p.p(n'en = ' || r.getc('en', 'null'));
		p.p(n'utf r.getc() func = ' || r.getc('utf', 'null'));
		r.getc('utf', vc, 'null');
		p.p(n'utf r.getc() procedure varchar2 = ' || vc);
		r.getc('utf', nvc, 'null');
		p.p(n'utf r.getc() procedure nvarchar2 = ' || nvc);
		p.div_close;
	
		p.hn(3, 'APIs that can specify what charset to use for request parameter parsing');
		p.div_open;
		p.p('h.content_type(charset) : set both the output charset and request charset.');
		p.p('r.req_charset(cs) : set request charset by "cs".');
		p.p('r.req_charset_utf8 : set request charset by "utf-8", it''s the default.');
		p.p('r.req_charset_db : set request charset as the db varchar2 used charset.');
		p.p('You can use form''s accept-charset=xxx attribure to specify what charset will the form submit use.');
		p.div_close;
	
		-- basic_io_b.req_info
		p.form_open('f', 'form', method => 'post'); -- accept-charset="gbk"
		p.input_text('url', 'http://www.google.com?q=HELLO');
		p.input_text('ch', '中文');
		p.input_text('en', 'english');
		p.input_text('utf', v_str);
		p.input_submit();
		p.form_close;
	
		p.script_text('f.onsubmit = function() {

		}');
	end;

	procedure test is
	begin
		--h.content_type('text/html', 'utf-8');
		h.content_type('text/html', 'GBK');
		-- h.content_encoding_try_zip;
		h.content_encoding_identity;
		p.h;
		for i in 1 .. 1000 loop
			for j in 1 .. 20 loop
				p.p('李勇');
			end loop;
			h.line('<br/>');
			-- h.flush;
			if false and mod(i, 100) = 0 then
				dbms_lock.sleep(1);
			end if;
		end loop;
	end;

end charset_b;
/
