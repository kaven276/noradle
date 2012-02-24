create or replace package body psp_code_gen_b is

	gv_distinct_names owa.vc_arr;
	gv_multiple       owa.vc_arr;

	procedure form_handler
	(
		name_array  owa.vc_arr,
		value_array owa.vc_arr
	) is
		v_cnt      integer := name_array.count;
		v_action   varchar2(100) := value_array(1);
		v_pos      pls_integer;
		v_pack     varchar2(30);
		v_proc     varchar2(100) := name_array(1);
		v_last     varchar2(4000);
		v_type     varchar2(100);
		v_multiple boolean;
		v_len      integer := 1;
	begin

		v_pos  := instr(v_action, '.');
		v_pack := substr(v_action, 1, v_pos - 1);
		v_proc := substr(v_action, v_pos + 1);

		psp_page_header_b.print;
		p.p('form.action="' || v_action || '"');
		p.ol_open;
		for i in 2 .. name_array.count loop
			p.li(name_array(i) || ' = ' || value_array(i));
		end loop;
		p.ol_close;

		v_last     := name_array(2);
		v_multiple := false;
		for i in 3 .. v_cnt loop
			if v_last = name_array(i) then
				v_multiple := true;
				continue;
			end if;
			gv_distinct_names(v_len) := v_last;
			gv_multiple(v_len) := case when v_multiple then 'owa.vc_arr' else 'varchar2' end;
			v_last := name_array(i);
			v_multiple := false;
			v_len := v_len + 1;
		end loop;
		gv_distinct_names(v_len) := v_last;
		gv_multiple(v_len) := case when v_multiple then 'owa.vc_arr' else 'varchar2' end;

		-- package spec part
		p.div_open(ac => st('atomicselection=true;'));
		p.pre_open;
		p.line('procedure ' || v_proc);
		p.line('(');
		for i in 1 .. v_len loop
			p.line(gv_distinct_names(i) || ' ' || gv_multiple(i) || ',');
		end loop;
		p.line(');');
		p.pre_close;
		p.div_close;

		-- package body part
		p.div_open(ac => st('atomicselection=true;'));
		p.pre_open;
		p.line('procedure ' || v_proc);
		p.line('(');
		for i in 1 .. v_len loop
			p.line(gv_distinct_names(i) || ' ' || gv_multiple(i) || ',');
		end loop;
		p.line(') is');
		p.line('begin');
		p.line('  null;');
		p.line('/*');
		for i in 1 .. v_len loop
			p.line('v.' || substr(gv_distinct_names(i), 3) || ' := ' || gv_distinct_names(i) || ';');
		end loop;
		p.line('*/');
		p.line('end;');
		p.line('');
		p.pre_close;
		p.div_close;

	end;

end psp_code_gen_b;
/

