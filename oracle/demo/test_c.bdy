create or replace package body test_c is

	procedure do is
	begin
		-- do db change
		h.status_line(200);
		h.content_type;
		h.header_close;

		p.doc_type('5');
		p.h;
		p.ul_open;
		-- p.css_link;
		p.li('abc');
		p.li('123');
		p.ul_close;
	end;

	-- 201——提示知道新文件的URL
	procedure do_201 is
	begin
		h.status_line(201);
		h.location('test_b.d');
		h.header_close;
	end;

	-- 202——接受和处理、但处理未完成
	procedure do_202 is
	begin
		h.status_line(202);
		h.header_close;
	end;

	-- 203——返回信息不确定或不完整
	procedure do_203 is
	begin
		h.status_line(203);
		h.header_close;
	end;

	-- 204——请求收到，但返回信息为空
	procedure do_204 is
	begin
		h.status_line(204);
		h.header_close;
	end;

	-- 205——服务器完成了请求，用户代理必须复位当前已经浏览过的文件
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
		p.h;
		p.hn(2, 'status 412 Precondition Failed');
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
