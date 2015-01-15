create or replace package body http_b is

	procedure gzip is
	begin
		case r.getc('use', 'on')
			when 'on' then
				h.content_encoding_try_zip;
			when 'off' then
				h.content_encoding_identity;
			when 'auto' then
				h.content_encoding_auto;
		end case;
	
		src_b.link_proc;
		h.line('This page gzip setting is ' || r.getc('use', 'auto') || '<br/>');
		h.line('This page print ' || r.getc('count', 100) || ' numbers <br/>');
		h.line('<br/>');
	
		h.line('<form action="http_b.gzip">');
		h.line('gzip options: ');
		h.line('<input name="use" type="radio" value="on" checked/>');
		h.line('<label>ON(if support)</label>');
		h.line('<input name="use" type="radio" value="off"/>');
		h.line('<label>OFF</label>');
		h.line('<input name="use" type="radio" value="auto"/>');
		h.line('<label>AUTO(if support and response deserve for zip)</label>');
		h.line('<br/>');
		h.line('how many numbers to print: ');
		h.line('<input name="count" type="text" value="' || r.getc('count', 100) || '">');
		h.line('<br/>');
		h.line('<input type="submit"/>');
		h.line('</form>');
		h.line('<br/>');
	
		for i in 1 .. r.getc('count', 100) loop
			h.line(i || '<br/>');
		end loop;
	end;

	procedure chunked_transfer is
	begin
		h.content_encoding_identity;
		h.header_close;
	
		h.line('<link href="http_b.content_css" type="text/css" rel="stylesheet"/>');
		h.line('<script src="http_b.content_js"></script>');
		src_b.link_proc;
		h.line('This page transfer-encoding setting is ' || r.getc('use', 'on') || '<br/>');
		h.line('This page print ' || r.getc('count', 100) || ' numbers <br/>');
		h.line('<br/>');
	
		h.line('<form action="http_b.chunked_transfer">');
		h.line('flush in half way(chunked transfer) options: ');
		h.line('<input name="use" type="radio" value="on"/>');
		h.line('<label>ON</label>');
		h.line('<input name="use" type="radio" value="off"/>');
		h.line('<label>OFF</label>');
		h.line('<br/>');
		h.line('how many numbers to print: ');
		h.line('<input name="count" type="text" value="' || r.getc('count', 100) || '">');
		h.line('<br/>');
		h.line('<input type="submit"/>');
		h.line('</form>');
		h.line('When this page is print out at this point, it will wait a while for big data processing.<br/>');
		h.line('So it should use "h.flush" API to send the already generated part to client/browser.<br/>');
		h.line(x.e('You call h.flush after <head><script><link> to load referenced files early, before body is generated.<br/>'));
		h.line('Call h.flush will use chunked transfer-encode mode instead of the default Content-Length mode<br/>');
	
		if r.getc('use', 'on') = 'on' then
			h.flush;
		end if;
	
		dbms_lock.sleep(2);
	
		for i in 1 .. r.getc('count', 100) loop
			h.line(i || '<br/>');
		end loop;
	end;

	procedure long_job is
	begin
		h.set_line_break(chr(10));
		h.header_close;
		-- h.auto_chunk_max_idle(0.5, 10);
	
		src_b.link_proc;
		h.line('<h3>This a long-running page that use chunked transfer and flush by section to response early</h3>');
		h.line('<div id="cnt"></div>');
		h.line('<script>var cnt=document.getElementById("cnt");</script>');
		h.line('<pre>');
		for i in 1 .. 9 loop
			h.line('LiNE, NO.' || i);
			h.line('<script>cnt.innerText=' || i || ';</script>');
			-- h.line(rpad(i, 300, i));
			h.flush;
			-- you may not force flush when h.auto_chunk_max_idle is set.
			-- but you can close auto flush by call h.auto_chunk_max_idle(null);
			dbms_lock.sleep(1);
		end loop;
		h.line('</pre>');
		h.line('<p>Over, Full page is generated completely</p>');
	end;

	procedure content_type is
		procedure mime_link(mime varchar2) is
		begin
			h.line('<a target="_blank" href="http_b.content_type?mime=' || mime || '"> open ' || mime ||
						 ' edition to new window </a><br/>');
		end;
	begin
		h.content_type(r.getc('mime', 'text/html'));
	
		h.line('<html>');
		h.line('<head>');
	
		if r.getc('mime', 'text/html') = 'text/html' then
			h.line('<link href="http_b.content_css" rel="stylesheet" type="text/css"/>');
			h.line('<script src="http_b.content_js"></script>');
		end if;
	
		h.line('</head>');
		h.line('<body>');
	
		if r.getc('mime', 'text/html') = 'text/html' then
			src_b.link_proc;
			h.line('<br/>');
		
			mime_link('text/html');
			mime_link('text/plain');
			mime_link('text/xml');
		
			mime_link('application/msword');
			mime_link('application/vnd.ms-excel');
			mime_link('application/vnd.ms-powerpoint');
			mime_link('application/octet-stream');
		
			h.line('<a href="http_b.content_css" target="_blank">view linked css (http_b.content_css)</a><br/>');
			h.line('<a href="http_b.content_js" target="_blank">view included js (http_b.content_js)</a><br/>');
		end if;
	
		h.line('<style>a{line-height:1.5em;text-decoration:none;}</style>');
		h.line('<div>');
		h.line('<h1> document header </h1>');
		h.line('<h3>You can use h.content_type API to specify what you output to the http entity body.</h3>');
		h.line('<h3>' || 'This is a ' || r.getc('mime', 'text/html') || ' mime-typed page' || '</h3>');
		h.line('<p>paragraph 1</p>');
		h.line('<p>paragraph 2</p>');
		h.line('<p>paragraph 3</p>');
		h.line('</div>');
		h.line('<table rules="all" style="border:1px solid red;">');
		h.line('<tr><td>A1</td><td>B1</td></tr><tr>');
		h.line('<td>A2</td><td>B2</td></tr>');
		h.line('</table>');
		h.line('</body>');
		h.line('</html>');
	
	end;

	procedure content_css is
	begin
		h.content_type(mime_type => 'text/css');
		h.content_type(h.mime_css);
		h.line('body {background-color:silver;}');
	end;

	procedure content_js is
	begin
		h.content_type(mime_type => 'application/x-javascript');
		h.line('alert("javascript speaking");');
	end;

	procedure refresh is
	begin
		h.refresh(r.getn('interval', 3, '9'), r.getc('to', ''));
		src_b.link_proc;
		h.line('<pre>');
		h.line(t.dt2s(sysdate));
		h.line('refresh to ' || r.getc('to', 'self') || ' every ' || r.getn('interval', 3) || 's');
		h.line('</pre>');
	end;

	procedure content_md5 is
	begin
		h.content_md5_on;
		if false then
			-- md5 is computed in Oracle
			h.content_encoding_identity;
		else
			-- md5 is computed in NodeJS;
			null;
		end if;
		src_b.link_proc;
		x.p('<p>', 'Use http content-md5 header to ensure response body integrity.');
		x.p('<p>', 'Call h.conent_md5_on to automatically compute md5 of response body and set content-md5 header.');
		x.p('<p>', 'Content MD5 for the same page is diffrent for diffrent Content-Encoding');
	end;

end http_b;
/
