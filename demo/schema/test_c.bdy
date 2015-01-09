create or replace package body test_c is

	procedure do is
	begin
		-- do db change
		h.status_line(200);
		h.content_type;
		h.header_close;
	
		pc.h;
		x.o('<ul>');
		x.p(' <li>', 'abc');
		x.p(' <li>', '123');
		x.c('</ul>');
	end;

	-- 201 tip for the newly created file's URL
	procedure do_201 is
	begin
		h.status_line(201);
		h.location('test_b.d');
		h.header_close;
	end;

	-- 202 accept and processing, but not done completely
	procedure do_202 is
	begin
		h.status_line(202);
		h.header_close;
	end;

	-- 203 infomation is not sure or not complete
	procedure do_203 is
	begin
		h.status_line(203);
		h.header_close;
	end;

	-- 204 accept, but return null response
	procedure do_204 is
	begin
		h.status_line(204);
		h.header_close;
	end;

	-- 205 processed, but UA must
	procedure do_205 is
	begin
		h.status_line(205);
		h.header_close;
	end;

	-- 412 Precondition Failed
	procedure do_412 is
	begin
		h.status_line(412);
		h.header_close;
		pc.h;
		x.p('<h2>', 'status 412 Precondition Failed');
	end;

	procedure do_303 is
	begin
		h.status_line(303);
		h.location('test_b.d');
		h.header_close;
	end;

	procedure do_303_retry_alfter is
	begin
		h.status_line(303);
		h.location('test_b.d');
		--h.retry_after(10);
		h.retry_after(sysdate + 10 / 24 / 60 / 60);
		h.header_close;
	end;

end test_c;
/
