create or replace package body test_c is

	procedure do is
	begin
		-- do db change
		h.status_line(200);
		h.content_type;
		h.header_close;
	
		p.init;
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
		p.init;
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

	procedure echo_http_body is
		v_line varchar2(200);
	begin
		h.content_type('text/plain');
		h.header_close;
		case 3
			when 1 then
				p.init;
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
				p.init;
				p.h;
				r.read_line_init(chr(10));
				for i in 1 .. 5 loop
					r.read_line(v_line);
					p.line(i);
					p.line(v_line);
					exit when r.read_line_no_more;
				end loop;
				p.html_tail;
		end case;
	end;

end test_c;
/
