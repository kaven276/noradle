create or replace package body msg_b is

	procedure print_items is
		cur sys_refcursor;
	begin
		dbms_lock.sleep(r.getn('delay', 0));
		h.content_type('text/resultsets', 'UTF-8');
		--h.content_type(h.rss, 'UTF-8');
		h.header('_convert', 'JSON');
	
		open cur for
			select sysdate from dual;
		rs.print('now', cur);
	
		-- receive from pipe data as message source
		-- and print it out
		-- pending message may more than limit of pipe store capacity
	end;

	procedure sendout_single is
		cur   sys_refcursor;
		v_msg varchar2(4000);
	begin
		tmp.n := dbms_pipe.receive_message('bbs', r.getn('timeout', 3));
		if tmp.n = 1 then
			h.status_line(504);
			return;
		end if;
	
		h.content_type('text/resultsets', 'UTF-8');
		h.header('_convert', 'JSON');
	
		dbms_pipe.unpack_message(v_msg);
		open cur for
			select v_msg msg_text from dual;
		rs.print('msg', cur);
	end;

	procedure sendout_batch is
		cur       sys_refcursor;
		v_msg     varchar2(4000);
		v_timeout number := r.getn('timeout', 3);
	begin
		loop
			tmp.n     := dbms_pipe.receive_message('bbs', v_timeout);
			v_timeout := 0;
			if tmp.n = 1 then
				h.status_line(504);
				return;
			end if;
		
			h.content_type('text/resultsets', 'UTF-8');
			h.header('_convert', 'JSON');
		
			dbms_pipe.unpack_message(v_msg);
			open cur for
				select v_msg msg_text from dual;
			rs.print('msg', cur);
		end loop;
	end;

	procedure say_something is
	begin
		x.t('<doctype HTML>');
		x.o('<form action=msg_c.say_something>');
		x.s(' <input type=text,name=message>');
		x.s(' <input type=submit>');
		x.c('</form>');
	end;

	procedure compute_callout is
		p1        number;
		p2        number;
		v_timeout number := r.getn('timeout', 2);
	begin
		tmp.n := dbms_pipe.receive_message('compute', v_timeout);
		if tmp.n = 1 then
			h.status_line(504);
			x.t('listen callout message timeout!');
			return;
		end if;
		dbms_pipe.unpack_message(p1);
		x.t(p1);
		x.t(chr(10));
		dbms_pipe.unpack_message(p2);
		x.t(p2);
	end;

	procedure resp_oper_result is
		v_pipename varchar2(100) := r.getc('h$pipename');
	begin
		dbms_pipe.pack_message(r.getc('oper'));
		dbms_pipe.pack_message(r.getn('result'));
		tmp.n := dbms_pipe.send_message(v_pipename);
	end;

	procedure compute is
		v_result number;
	begin
		dbms_pipe.pack_message(r.getn('p1', 3));
		dbms_pipe.pack_message(r.getn('p2', 5));
		tmp.n := dbms_pipe.send_message('compute');
	
		tmp.n := dbms_pipe.receive_message('cb', 15);
		if tmp.n = 1 then
			-- callout timeout
			h.status_line(504);
			x.t('callout timeout!');
			return;
		end if;
	
		dbms_pipe.unpack_message(v_result);
		x.t(v_result);
	end;

	procedure direct_sendout is
		v_result number;
	begin
		dbms_pipe.pack_message(r.getc('oper', 'add'));
		dbms_pipe.pack_message(r.getn('p1', 3));
		dbms_pipe.pack_message(r.getn('p2', 5));
		tmp.n := dbms_pipe.send_message('direct_send_pipe');
		x.t('message send, no code for customized message printer');
		return;
	end;

	procedure direct_callout is
		v_oper      varchar2(30);
		v_result    number;
		v_rpipename varchar2(100) := r.cfg || '.' || r.slot;
	begin
		dbms_pipe.pack_message(r.getc('oper', 'add'));
		dbms_pipe.pack_message(r.getn('p1', 3));
		dbms_pipe.pack_message(r.getn('p2', 5));
		dbms_pipe.pack_message(v_rpipename);
		tmp.n := dbms_pipe.send_message('direct_send_pipe');
	
		dbms_pipe.purge(v_rpipename);
		tmp.n := dbms_pipe.receive_message(v_rpipename, 15);
		if tmp.n = 1 then
			-- callout timeout
			h.status_line(504);
			x.t('callout timeout!');
			return;
		end if;
	
		dbms_pipe.unpack_message(v_oper);
		x.t(v_oper || ':');
		dbms_pipe.unpack_message(v_result);
		x.t(v_result);
	end;

	procedure multiple_callout is
		v_result    number;
		v_rpipename varchar2(100) := r.cfg || '.' || r.slot;
		p1          number := r.getn('p1', 5);
		p2          number := r.getn('p2', 3);
		v_oper      varchar2(30);
		v_opers     varchar2(100);
		v_add       number;
		v_minus     number;
		v_multiply  number;
	begin
		-- clear receive reponse pipe first
		dbms_pipe.purge(v_rpipename);
	
		-- callout 1  
		dbms_pipe.pack_message('add');
		dbms_pipe.pack_message(p1);
		dbms_pipe.pack_message(p2);
		dbms_pipe.pack_message(v_rpipename);
		tmp.n := dbms_pipe.send_message('direct_send_pipe');
	
		-- callout 2
		dbms_pipe.pack_message('minus');
		dbms_pipe.pack_message(p1);
		dbms_pipe.pack_message(p2);
		dbms_pipe.pack_message(v_rpipename);
		tmp.n := dbms_pipe.send_message('direct_send_pipe');
	
		-- callout 3
		dbms_pipe.pack_message('multiply');
		dbms_pipe.pack_message(p1);
		dbms_pipe.pack_message(p2);
		dbms_pipe.pack_message(v_rpipename);
		tmp.n := dbms_pipe.send_message('direct_send_pipe');
	
		-- receive all the callout response, with any order
		for i in 1 .. 3 loop
			tmp.n := dbms_pipe.receive_message(v_rpipename, 15);
			if tmp.n = 1 then
				-- callout timeout
				h.status_line(504);
				x.t('callout timeout!');
				return;
			end if;
		
			dbms_pipe.unpack_message(v_oper);
			v_opers := v_opers || v_oper || ',';
			case v_oper
				when 'add' then
					dbms_pipe.unpack_message(v_result);
					v_add := v_result;
				when 'minus' then
					dbms_pipe.unpack_message(v_result);
					v_minus := v_result;
				when 'multiply' then
					dbms_pipe.unpack_message(v_result);
					v_multiply := v_result;
				else
					null;
			end case;
		end loop;
	
		x.p('<p>', 'p1:' || p1);
		x.p('<p>', 'p2:' || p2);
		x.p('<p>', 'response receive order:' || v_opers);
		x.p('<p>', 'add:' || v_add);
		x.p('<p>', 'minus:' || v_minus);
		x.p('<p>', 'multiply:' || v_multiply);
	end;

	procedure multiple_callout_easy_resp is
		v_result    number;
		v_rpipename varchar2(100) := r.cfg || '.' || r.slot;
		p1          number := r.getn('p1', 5);
		p2          number := r.getn('p2', 3);
		v_oper      varchar2(30);
		v_opers     varchar2(100);
		v_add       number;
		v_minus     number;
		v_multiply  number;
	begin
		-- clear receive reponse pipe first
		dbms_pipe.purge(v_rpipename);
	
		-- callout 1  
		dbms_pipe.pack_message('add');
		dbms_pipe.pack_message(p1);
		dbms_pipe.pack_message(p2);
		dbms_pipe.pack_message(v_rpipename);
		tmp.n := dbms_pipe.send_message('pipe_only');
	
		-- callout 2
		dbms_pipe.pack_message('minus');
		dbms_pipe.pack_message(p1);
		dbms_pipe.pack_message(p2);
		dbms_pipe.pack_message(v_rpipename);
		tmp.n := dbms_pipe.send_message('pipe_only');
	
		-- callout 3
		dbms_pipe.pack_message('multiply');
		dbms_pipe.pack_message(p1);
		dbms_pipe.pack_message(p2);
		dbms_pipe.pack_message(v_rpipename);
		tmp.n := dbms_pipe.send_message('pipe_only');
	
		-- receive all the callout response, with any order
		for i in 1 .. 3 loop
			if not mp.pipe2param(v_rpipename, 15) then
				-- callout timeout
				h.status_line(504);
				x.t('callout timeout!');
				return;
			end if;
			v_oper   := r.getc('oper');
			v_result := r.getn('result');
		
			v_opers := v_opers || v_oper || ',';
			case v_oper
				when 'add' then
					v_add := v_result;
				when 'minus' then
					v_minus := v_result;
				when 'multiply' then
					v_multiply := v_result;
				else
					null;
			end case;
		end loop;
	
		x.p('<p>', 'p1:' || p1);
		x.p('<p>', 'p2:' || p2);
		x.p('<p>', 'response receive order:' || v_opers);
		x.p('<p>', 'add:' || v_add);
		x.p('<p>', 'minus:' || v_minus);
		x.p('<p>', 'multiply:' || v_multiply);
	end;

	procedure sync_sendout is
	begin
		x.p('<p>', 'a call-out message is send as this page is produced!');
		mp.begin_msg;
		h.header('Content-Type', 'text/xml');
		h.header('Msg-Type', 'type1');
		x.p('<message>', 'I am sent with servlet to nodejs.');
		mp.send_msg;
		x.p('<p>', 'printed after message sent.');
	end;

	procedure sync_sendout2 is
		cur sys_refcursor;
	begin
		x.p('<p>', 'a call-out message is send as this page is produced!');
		mp.begin_msg;
		h.header('Content-Type', 'text/resultsets');
		h.header('Msg-Type', 'type2');
		open cur for
			select * from user_t where rownum <= 3;
		rs.print('users', cur);
		mp.send_msg;
		x.p('<p>', 'printed after message sent.');
	end;

	procedure sync_sendout3 is
	begin
		x.p('<p>', 'a call-out message is send as this page is produced!');
		mp.begin_msg;
		h.header('Content-Type', 'text/items');
		h.header('Msg-Type', 'type3');
		for i in (select * from user_t where rownum <= 3) loop
			h.line(i.name);
		end loop;
		mp.send_msg;
		x.p('<p>', 'printed after message sent.');
	end;

	procedure sync_sendout4 is
	begin
		x.p('<p>', 'a call-out message is send as this page is produced!');
		mp.begin_msg;
		mp.set_callback_pipename;
		h.header('Content-Type', 'text/items');
		h.header('Msg-Type', 'type4');
		h.line('Tianjin');
		mp.send_msg;
	
		if not mp.pipe2param then
			h.status_line(504);
			x.t('callout(get termperature) timeout!');
			return;
		end if;
		x.t('temperature is ' || r.getn('temperature') || ' degree');
	end;

end msg_b;
/
