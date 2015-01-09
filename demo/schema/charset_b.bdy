create or replace package body charset_b is

	procedure form is
		v_src varchar2(200) := 'E3818DCEA609D8A6D985D8B9D8AAD8AFD984E184ACE1B4ABE1BC8EE3818EE3839E';
		ncstr nvarchar2(100) := utl_i18n.raw_to_nchar(hextoraw(v_src), 'AL32UTF8');
		v_raw raw(4000);
		vc    varchar2(100);
		nvc   nvarchar2(100);
	begin
	
		ncstr := utl_i18n.raw_to_nchar(hextoraw(v_src), 'AL32UTF8');
	
		-- h.content_type(charset => 'GBK');
		h.allow_get_post;
		--h.header_close;
		pc.h(title => ncstr);
		src_b.link_proc;
		x.t('<br/>');
	
		x.p('<style>', 'div { border:1px dotted gray;margin:1em;padding:1em;}');
	
		x.p('<h3>', 'basic output API for nvarchar2');
		x.o('<div>');
	
		h.write('h.write : ');
		h.write(ncstr);
		h.line('<br/>');
	
		h.write('h.writeln : ');
		h.writeln(ncstr);
		h.line('<br/>');
	
		h.write('h.string : ');
		h.string(ncstr);
		h.line('<br/>');
	
		h.write('h.line : ');
		h.line(ncstr);
		h.line('<br/>');
	
		h.write('x.t : ');
		x.t(ncstr);
		h.line('<br/>');
	
		x.c('</div>');
	
		x.p('<h3>', 'other tag API using nvarchar2');
		x.o('<div>');
		h.write('x.p : ');
		x.p('<p>', ncstr);
		x.c('</div>');
	
		x.p('<h3>', 'function tag API using nvarchar2');
		x.o('<div>');
		h.write('x.p using function API: ');
		x.p('<p>', x.p('<span>', ncstr));
		h.write('x.a using function API: ');
		x.p('<p>', x.a('<a>', ncstr, n'form?a=' || ncstr));
		x.c('</div>');
	
		x.t('<br/>');
		x.p('<p>', utl_raw.cast_to_raw(substr(ncstr, 1, 1)));
		--x.p('<p>', utl_raw.cast_to_raw(convert(substr(v_str, 1, 1), 'AL32UTF8')));
	
		-- r.req_charset_utf8;
		x.p('<h3>', 'request parameters');
		x.o('<div>');
		x.p(' <p>', n'url = ' || r.getc('url', 'null'));
		x.p(' <p>', n'ch = ' || r.getc('ch', 'null'));
		x.p(' <p>', n'en = ' || r.getc('en', 'null'));
		x.p(' <p>', n'utf r.getc() func = ' || r.getc('utf', 'null'));
		vc := r.getc('utf', 'null');
		x.p(' <p>', n'utf r.getc() procedure varchar2 = ' || vc);
		nvc := r.getnc('utf', 'null');
		x.p(' <p>', n'utf r.getc() procedure nvarchar2 = ' || nvc);
		x.c('</div>');
	
		x.p('<h3>', 'APIs that can specify what charset to use for request parameter parsing');
		x.o('<div>');
		x.p(' <p>', 'h.content_type(charset) : set both the output charset and request charset.');
		x.p(' <p>', 'r.req_charset(cs) : set request charset by "cs".');
		x.p(' <p>', 'r.req_charset_utf8 : set request charset by "utf-8", it''s the default.');
		x.p(' <p>', 'r.req_charset_db : set request charset as the db varchar2 used charset.');
		x.p(' <p>', 'You can use form''s accept-charset=xxx attribure to specify what charset will the form submit use.');
		x.c('</div>');
	
		-- basic_io_b.req_info
		x.o('<form name=f,action=charset_b.form,method=post>'); -- accept-charset="gbk"
		x.v(' <input type=text,name=url>', 'http://www.google.com?q=HELLO');
		x.v(' <input type=ch,name=url>', 'ÖÐÎÄ');
		x.v(' <input type=text,name=en>', 'english');
		x.v(' <input type=text,name=utf>', ncstr);
		x.s(' <input type=submit>');
		x.c('</form>');
	
		x.p('<script>', 'f.onsubmit = function(){}');
	end;

	procedure test is
	begin
		--h.content_type('text/html', 'utf-8');
		h.content_type('text/html', 'GBK');
		-- h.content_encoding_try_zip;
		h.content_encoding_identity;
		pc.h;
		for i in 1 .. 1000 loop
			for j in 1 .. 20 loop
				x.p('<p>', 'ÀîÓÂ');
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
