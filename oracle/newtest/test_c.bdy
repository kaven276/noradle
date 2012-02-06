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

end test_c;
/
