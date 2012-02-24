create or replace package body proxy_b is

	procedure processor
	(
		name_array  owa.vc_arr,
		value_array owa.vc_arr
	) is
		v_pipe_name varchar2(100);
		v_result    number;
		i           number;
		v_count     number := name_array.count - 1;
	begin
		null;
		-- do write temporary clob table
		-- and alert to fetch
		-- temp table has a trigger to do the alert
		v_pipe_name := value_array(1);
		-- dbms_pipe.purge(v_pipe_name);
		-- v_result := dbms_pipe.create_pipe(v_pipe_name, 8192 * 2000, false);
		dbms_pipe.pack_message(v_count);
		v_result := dbms_pipe.send_message(v_pipe_name, 1, 8192 * 100);

		p.h;
		p.p(v_result);
		p.p(v_pipe_name);
		p.p(name_array.count - 1);
		for i in 2 .. name_array.count loop
			dbms_pipe.pack_message(name_array(i));
			dbms_pipe.pack_message(value_array(i));
			v_result := dbms_pipe.send_message(v_pipe_name);
			p.div_open;
			p.b(name_array(i));
			p.a(value_array(i));
			p.div_close;
		end loop;
	exception when others then
	 p.h;
	 p.b(SQLCODE);
	 p.a(SQLERRM);
	end;

	procedure main is
	begin
		p.doc_type('frameset');
		p.html_open;
		p.head_open;
		p.title('代理主页面');
		p.link('u:.css');
		p.script('u:.js');
		p.head_close;
		p.frameset_open(cols => '*,*', rows => '*,*', frameborder => 'yes');
		p.frame('wait_signal_frm');
		p.frame('ori_page_frm');
		p.frame('form_frm', 'u:form');
		p.frame('submit_tar_frm');
		p.frameset_close;
		p.html_close;
	end;

	procedure form is
	begin
		p.h;
	end;

end proxy_b;
/

