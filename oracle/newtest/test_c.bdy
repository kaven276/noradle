create or replace package body test_c is

	procedure do is
	begin
		-- do db change
		h.status_line(200);
		h.content_type;
		h.http_header_close;
	
		p.init;
		p.doc_type('5');
		p.h;
		p.ul_open;
		-- p.css_link;
		p.li('abc');
		p.li('123');
		p.ul_close;
	end;

	procedure do_303 is
	begin
		h.status_line(303);
		h.location('test_b.d');
		h.http_header_close;
	end;

	procedure do_303_retry_alfter is
	begin
		h.status_line(303);
		h.location('test_b.d');
		--h.retry_after(10);
		h.retry_after(sysdate + 10 / 24 / 60 / 60);
		h.http_header_close;
	end;

end test_c;
/
