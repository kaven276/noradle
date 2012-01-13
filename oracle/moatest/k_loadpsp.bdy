create or replace package body k_loadpsp is

	nl varchar2(1) := chr(10);

	procedure compile(tpl varchar2) is
		vst st;
		n   varchar2(63);
		src varchar2(32000);
		b   varchar2(20) := nl || 'p.prn(''';
		e   varchar2(10) := ''');' || nl;
	begin
		--dbms_output.put_line(dbms_utility.format_call_stack);return;
		t.split(vst, dbms_utility.format_call_stack, nl);
		n   := lower(regexp_substr(vst(5), '(\w+\.\w+)_S$', subexpression => 1)) || '_b';
		src := regexp_replace(tpl, '^\s*-(.*)\s*$', e || '\1' || b, 1, 0, 'im');
		src := regexp_replace(src, '\[=(.+?)\]', e || 'p.prn(\1);' || b, 1, 0, 'im');
		src := regexp_replace(src, '\[-(.+?)\]', e || 'p.prn(htf.escape_sc(\1));' || b, 1, 0, 'im');
		src := replace(src, 'p.prn(''' || nl, 'p.prn(''');
		-- src := replace(src, nl || ''');', ''');');
		src := replace(b || src || e, 'p.prn('''');' || nl, '');
		src := 'create or replace procedure ' || n || '
as
begin
	p.h;' || src || 'end;';
		dbms_output.put_line(src);
		execute immediate src;
	end;

	procedure haml(tpl varchar2) is
		vst   st;
		n     varchar2(63);
		src   varchar2(32000);
		b     varchar2(20) := nl || 'p.prn(''';
		e     varchar2(10) := ''');' || nl;
		tpl2  varchar2(32000);
		lines st;
		stack st := st();
		tag   varchar2(100);
		lvl   pls_integer;
		dat   varchar2(1000);
		cls   varchar2(1000);
	begin
		t.split(vst, dbms_utility.format_call_stack, nl);
		n := lower(regexp_substr(vst(5), '(\w+\.\w+)_S$', subexpression => 1)) || '_b';
		t.split(lines, tpl, nl);
	
		for i in 1 .. lines.count loop
			if regexp_like(lines(i), '^\s*`.*') or regexp_like(lines(i), '^\s*$') or lines(i) is null then
				continue;
			end if;
			tag := regexp_substr(lines(i), '^\s*(\w+)\s?', subexpression => 1);
			lvl := length('`' || regexp_substr(lines(i), '^(\s*)\w', subexpression => 1));
			dat := regexp_substr(lines(i), '^\s*(\w+)\s(.*)$', subexpression => 2);
			lines(i) := '<' || tag || '>' || dat;
			cls := '';
			if lvl <= stack.count then
				for j in reverse lvl .. stack.count loop
					cls := cls || '</' || stack(j) || '>';
					stack.trim;
				end loop;
				lines(i) := cls || lines(i);
			end if;
		
			stack.extend;
			stack(stack.count) := tag;
			dbms_output.put_line(tag || ',' || stack.count || ',' || stack(stack.count));
		end loop;
	
		cls := nl;
		for j in reverse 1 .. stack.count loop
			cls := cls || '</' || stack(j) || '>';
			dbms_output.put_line(j);
		end loop;
		src := t.join(lines, nl) || cls;
		dbms_output.put_line(src);
	
		src := regexp_replace(src, '^\s*`(.*)\s*$', e || '\1' || b, 1, 0, 'im');
		src := regexp_replace(src, '``(.+?)(`|$)', '`htf.escape_sc(\1)`', 1, 0, 'im');
		src := regexp_replace(src, '`(.+?)(`|$)', e || 'p.prn(\1);' || b, 1, 0, 'im');
		src := replace(src, 'p.prn(''' || nl, 'p.prn(''');
		-- src := replace(src, nl || ''');', ''');');
		src := replace(b || src || e, 'p.prn('''');' || nl, '');
		src := 'create or replace procedure ' || n || '
as
begin
	p.h;' || src || 'end;';
		-- dbms_output.put_line(src);
		execute immediate src;
	end;

end k_loadpsp;
/

