create or replace package body src_b is

	procedure pack is
		n varchar2(30) := upper(r.getc('p'));
	begin
		h.content_type('text/plain');
		h.set_line_break('');
		for i in (select a.text
								from user_source a
							 where a.name = n
								 and a.type = 'PACKAGE BODY'
							 order by a.line) loop
			h.line(replace(i.text, chr(9), '  '));
		end loop;
	end;

	procedure proc is
		v_prog st;
		v_pack varchar2(30);
		v_proc varchar2(99);
		v_sts  boolean := false;
	begin
		t.split(v_prog, r.getc('p'), '.');
		v_pack := upper(v_prog(1));
		-- v_proc := chr(9) || 'procedure ' || v_prog(2) || ' is' || chr(10);
		v_proc := chr(9) || 'procedure ' || v_prog(2) || '%' || chr(10);
		h.content_type('text/plain');
		h.set_line_break('');
		for i in (select a.text
								from user_source a
							 where a.name = v_pack
								 and a.type = 'PACKAGE BODY'
							 order by a.line) loop
			if not v_sts then
				if i.text like v_proc and regexp_like(i.text, '\s' || v_prog(2) || '(\s|\()') then
					v_sts := true;
				end if;
			end if;
			if v_sts then
				h.line(replace(i.text, chr(9), '  '));
				if i.text = chr(9) || 'end;' || chr(10) then
					exit;
				end if;
			end if;
		end loop;
	end;

	procedure link_pack(pack varchar2 := null) is
	begin
		h.line(t.ps('<a href="src_b.pack?p=:1" target=":1">view pl/sql source pack ":1" in new window</a></br>',
								st(nvl(pack, r.pack))));
	end;

	procedure link_proc(proc varchar2 := null) is
	begin
		h.line(t.ps('<a href="src_b.proc?p=:1" target=":1">view pl/sql source proc ":1" in new window</a></br>',
								st(nvl(proc, r.prog))));
	end;

end src_b;
/
