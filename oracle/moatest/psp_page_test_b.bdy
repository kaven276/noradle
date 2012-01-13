create or replace package body psp_page_test_b is

	procedure para_form(p_page varchar2) is
		v_pack      varchar2(30);
		v_proc      varchar2(30);
		v_pos       integer;
		v_object_id integer;
		v_value     varchar2(4000);
	begin
		psp_page_header_b.print;
		p.a(p_page, p_page);
		v_pos  := instr(p_page, '.');
		v_pack := substr(p_page, 1, v_pos - 1);
		v_proc := substr(p_page, v_pos + 1);
		for i in (select t.*
								from dba_procedures t
							 where t.owner = user
								 and t.object_type = 'PACKAGE'
								 and t.object_name = v_pack
								 and t.procedure_name = v_proc) loop
			p.form_open('f_go_test', '!psp_page_test_b.save_para_and_go');
			p.input_hidden('p_page', p_page);
			p.table_open(rules => 'all');
			for j in (select *
									from dba_arguments t
								 where t.object_id = i.object_id
									 and t.subprogram_id = i.subprogram_id
									 and t.argument_name is not null
								 order by t.position asc) loop
				-- argument_name
				-- position
				-- data_type
				-- default_value
				-- default_length
				-- pls_type
				begin
					select t.para_value
						into v_value
						from pbld_last_para t
					 where t.schema = user
						 and t.page = p_page
						 and t.para_name = j.argument_name;
				exception
					when no_data_found then
						v_value := j.default_value;
				end;
				p.input_text(j.argument_name, v_value, j.argument_name || ':');
			end loop;
			p.table_close;
			p.br;
			p.input_submit(n, 'Go and test page: ' || p_page);
			p.form_close;
		end loop;
	end;

	procedure save_para_and_go
	(
		name_array  owa.vc_arr,
		value_array owa.vc_arr
	) is
		v_page varchar2(61);
		v_len  integer := name_array.count;
		v_url  varchar2(32000);
		v_char char(1) := '?';
	begin
		if name_array(1) != 'p_page' then
			raise_application_error(-20000, '没有给出是那个 page');
		end if;
		v_page := value_array(1);
		v_url  := lower(v_page);
		delete from pbld_last_para t
		 where t.schema = user
			 and t.page = v_page;
		for i in 2 .. v_len loop
			insert into pbld_last_para
				(schema, page, para_name, para_value)
			values
				(user, v_page, name_array(i), value_array(i));
			v_url  := v_url || v_char || lower(name_array(i)) || '=' || value_array(i);
			v_char := '&';
		end loop;
		p.go(v_url);
	end;

end psp_page_test_b;
/

