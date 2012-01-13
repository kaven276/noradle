create or replace package body js is
	pragma serially_reusable;

	nl constant char(1) := chr(13);
	gv_sep      varchar2(5);
	gv_hash_len pls_integer := 0;

	procedure ab(selector varchar2, params st) is
		v_name varchar2(100);
		v_val  varchar2(100);
	begin
		p.print('pw.bind("' || selector || '", "tree" {');
		for i in 1 .. params.count / 2 loop
			v_name := params(i * 2 - 1);
			v_val  := params(i * 2);
			case substr(v_name, 1, 1)
				when 'b' then
					v_val := params(i * 2);
				when 'n' then
					v_val := params(i * 2);
				when 's' then
					v_val := '"' || params(i * 2) || '"';
			end case;
			p.print(substr(v_name, 2) || ' : ' || v_val);
		end loop;
	end;

	procedure open_ab(selector varchar2, abname varchar2) is
	begin
		p.script_open;
		p.prn('pw.bind("' || selector || '", "' || abname || '", ');
		gv_sep := ' {' || nl || '  ';
	end;

	procedure close_ab is
	begin
		p.print(nl || '});');
		p.script_close;
	end;

	procedure add_number(name varchar2, val number) is
	begin
		if val is null then
			return;
		end if;
		p.prn(gv_sep || name || ' : ' || val);
		gv_sep := ' ,' || nl || '  ';
	end;

	procedure add_boolean(name varchar2, val boolean) is
	begin
		if val is null then
			return;
		end if;
		p.prn(gv_sep || name || ' : ' || case val when true then 'true' when false then 'false' end);
		gv_sep := ' ,' || nl || '  ';
	end;

	procedure add_string(name varchar2, val varchar2) is
	begin
		if val is null then
			return;
		end if;
		p.prn(gv_sep || name || ' : "' || val || '"');
		gv_sep := ' ,' || nl || '  ';
	end;

	procedure hash_item(name varchar2, value varchar2) is
	begin
		if gv_hash_len = 0 then
			p.gv_texts  := st();
			p.gv_values := st();
		end if;
		gv_hash_len := gv_hash_len + 1;
		p.gv_texts.extend;
		p.gv_values.extend;
		p.gv_texts(gv_hash_len) := name;
		p.gv_values(gv_hash_len) := value;
	end;

	procedure add_hash(name varchar2) is
	begin
		p.line(gv_sep || name || ' : {');
		for i in 1 .. gv_hash_len - 1 loop
			p.line('    ' || p.gv_texts(i) || ' : "' || p.gv_values(i) || '",');
		end loop;
		p.line('    ' || p.gv_texts(gv_hash_len) || ' : "' || p.gv_values(gv_hash_len) || '"');
		p.prn('  }');
		p.gv_texts  := null;
		p.gv_values := null;
		gv_hash_len := 0;
	end;

	-- b/n/s

	procedure ab_tree(selector varchar2 := '.pwb_tree', init_level pls_integer := null, toggle_event varchar2 := null,
										hold boolean := null, unique_path boolean := null, expand_url varchar2 := null,
										effect_range varchar2 := null, content_frame_name varchar2 := null, path_container varchar2 := null) is
	begin
		open_ab(selector, 'tree');
		add_number('init_level', init_level);
		add_string('toggle_event', toggle_event);
		add_boolean('hold', hold);
		add_boolean('unique_path', unique_path);
		add_string('expand_url', expand_url);
		add_string('effect_range', effect_range);
		add_string('content_frame_name', content_frame_name);
		add_string('path_container', path_container);
		close_ab;
	end;

	procedure ab_tabpage(selector varchar2 := '.pwb_tabpage', toggle_event varchar2 := null) is
	begin
		open_ab(selector, 'tabpage');
		add_string('toggle_event', toggle_event);
		close_ab;
	end;

	------------------------

	procedure call(name varchar2) is
	begin
		p.line(name || '();');
	end;

	procedure call(name varchar2, val varchar2) is
	begin
		p.line(name || '("' || val || '");');
	end;

	procedure call(name varchar2, vals st) is
	begin
		p.prn(name || '(');
		for i in 1 .. vals.count - 1 loop
			p.prn('"' || vals(i) || '",');
		end loop;
		p.line('"' || vals(vals.count) || '");');
	end;

	procedure set(name varchar2, val varchar2) is
	begin
		p.line(name || '="' || val || '";');
	end;

	procedure set(name varchar2, val number) is
	begin
		p.line(name || '=' || val || ';');
	end;

	procedure set(name varchar2, vals st) is
	begin
		p.prn(name || '=[');
		for i in 1 .. vals.count - 1 loop
			p.prn('"' || vals(i) || '",');
		end loop;
		p.line('"' || vals(vals.count) || '"];');
	end;

end js;
/

