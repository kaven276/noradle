create or replace package body ztag is

	procedure p
	(
		idx pls_integer,
		val varchar2
	) is
	begin
		tmp.p(idx) := val;
	end;

	procedure p
	(
		idx pls_integer,
		val boolean
	) is
	begin
		tmp.p(idx) := k_type_tool.tf(val);
	end;

	procedure p
	(
		idx pls_integer,
		val number
	) is
	begin
		tmp.p(idx) := to_char(val);
	end;

	--private
	procedure base
	(
		tag   varchar2,
		inner varchar2
	) is
		idx  pls_integer := 0; -- param index
		ls   char(1) := '<'; -- last separator
		ts   char(1); -- this separator
		pl   pls_integer := instrb(tag, '<') - 1; -- pos left
		pr   pls_integer; -- pos right
		pe   pls_integer := instrb(tag, '='); -- pos equal-sign only for compare
		cls  varchar2(1000);
		re   varchar2(10) := '[#. "/>]';
		sect varchar2(1000); -- current section
		err  varchar2(1000);
		procedure cut(more pls_integer := 0) is
			pre char(1);
			add boolean;
		begin
			if substrb(tag, pr - 1, 1) = '?' then
				pre := substrb(tag, pr - 2, 1);
				idx := idx + 1;
				-- a:97 z:122 0:48 9:57
				add := not (ascii(pre) between 97 and 122 or ascii(pre) between 48 and 57);
				if pre = '+' then
					sect := substrb(tag, pl + 1 - more, pr - pl - 3 + more) || tmp.p(idx);
				elsif add then
					sect := substrb(tag, pl + 1 - more, pr - pl - 2 + more) || tmp.p(idx);
				elsif tmp.p(idx) = 'true' then
					sect := substrb(tag, pl + 1 - more, pr - pl - 2 + more);
				else
					sect := '';
				end if;
			else
				sect := substrb(tag, pl + 1 - more, pr - pl - 1 + more);
			end if;
			if more = 1 and substrb(sect, 2, 1) = '-' then
				sect := ' data' || substrb(sect, 2);
			end if;
		end;
		procedure rpl is
			tc char(1) := substrb(tag, pr - 1, 1);
		begin
			sect := replace(substrb(tag, pl, pr - pl), '=', '="') || '"';
			if tc = '?' then
				idx  := idx + 1;
				sect := replace(substrb(tag, pl, pr - pl - 1), '=', '="') || tmp.p(idx) || '"';
			elsif tc = '"' then
				sect := substrb(tag, pl, pr - pl);
			else
				sect := replace(substrb(tag, pl, pr - pl), '=', '="') || '"';
			end if;
			if substrb(tag, pl + 1, 1) = '-' then
				sts.lstr := sts.lstr || ' data' || substr(sect, 2);
			else
				sts.lstr := sts.lstr || sect;
			end if;
		end;
	begin
		if pl = -1 then
			-- case: plain text
			sts.lstr := null;
			sts.rstr := ltrim(tag);
			return;
		end if;
		if substrb(tag, pl + 2, 1) = '/' then
			-- case: </tag>
			sts.tagn := substrb(tag, pl + 1);
			sts.lstr := null;
			sts.rstr := substrb(tag, pl + 1);
			if substrb(sts.stack, 1, lengthb(sts.tagn)) != sts.tagn then
				err := 'tag open/close mismatch for ' || sts.stack || ',' || sts.tagn;
				raise_application_error(-20000, err);
			else
				sts.stack := substrb(sts.stack, lengthb(sts.tagn) + 1);
			end if;
			return;
		end if;
		if pe = 0 then
			pe := lengthb(tag);
		end if;
		idx := nvl(to_number(substrb(tag, instrb(tag, '>', -1) + 1)), 1) - 1;
		loop
			pr := regexp_instr(tag, re, pl + 1, 1, 0);
			exit when pr = 0;
			ts := substrb(tag, pr, 1);
			case ls
				when '<' then
					-- case: <tag
					cut(-1);
					sts.lstr := '<' || sect;
					sts.tagn := sect;
				when '#' then
					-- case: #id
					cut;
					if sect is not null then
						sts.lstr := sts.lstr || ' id="' || sect || '"';
					end if;
				when '.' then
					-- case: .class
					cut;
					if sect is not null then
						if cls is null then
							cls := sect;
						else
							cls := cls || ' ' || sect;
						end if;
					end if;
					if ts != '.' and cls is not null then
						sts.lstr := sts.lstr || ' class="' || cls || '"';
					end if;
				when ' ' then
					if pr <= pe then
						-- case: bool_attr, checked
						cut(1);
						if sect is not null then
							sts.lstr := sts.lstr || sect;
						end if;
					else
						-- case: name=value, name="value"
						if ts = '"' then
							pr := instrb(tag, '"', pr + 1) + 1;
							ts := substrb(tag, pr, 1);
						end if;
						rpl;
					end if;
				when '/' then
					-- case: <tag/> self close
					exit;
			end case;
			ls := ts;
			pl := pr;
		end loop;
	
		if inner = chr(0) then
			if ls = '/' then
				sts.rstr := '/>';
			else
				sts.rstr  := '>';
				sts.stack := '</' || sts.tagn || '>' || sts.stack;
			end if;
		else
			sts.rstr := '>' || inner || '</' || sts.tagn || '>';
		end if;
	end;

	procedure t
	(
		tag   varchar2,
		inner varchar2 := chr(0)
	) is
	begin
		base(tag, inner);
		if sts.lstr is not null then
			b.l(sts.lstr || sts.rstr);
		else
			b.l(sts.rstr);
		end if;
	end;

	function t
	(
		tag   varchar2,
		inner varchar2 := chr(0)
	) return varchar2 is
	begin
		base(tag, inner);
		if sts.lstr is not null then
			return sts.lstr || sts.rstr;
		else
			return sts.rstr;
		end if;
	end;

	-- private
	function url_attr return varchar2 is
	begin
		if sts.tagn in ('a', 'link', 'base') then
			return 'href';
		elsif sts.tagn in ('img', 'script', 'iframe', 'frame') then
			return 'src';
		elsif sts.tagn = 'form' then
			return 'action';
		end if;
	end;

	procedure u
	(
		tag   varchar2,
		url   varchar2,
		inner varchar2 := chr(0)
	) is
	begin
		base(tag, inner);
		b.l(sts.lstr || ' ' || url_attr || '="' || l(url) || '"' || sts.rstr);
	end;

	function u
	(
		tag   varchar2,
		url   varchar2,
		inner varchar2 := chr(0)
	) return varchar2 is
	begin
		base(tag, inner);
		return sts.lstr || ' ' || url_attr || '="' || l(url) || '"' || sts.rstr;
	end;

	-- private
	function bool_attr(switch boolean) return varchar2 is
	begin
		if switch is null or switch = false then
			return '';
		else
			if sts.tagn = 'option' then
				return ' selected';
			elsif sts.tagn = 'input' then
				return ' checked';
			else
				return '';
			end if;
		end if;
	end;

	procedure v
	(
		tag    varchar2,
		value  varchar2,
		switch boolean := null
	) is
	begin
		base(tag, chr(0));
		b.l(sts.lstr || ' value="' || value || '"' || bool_attr(switch) || sts.rstr);
	end;

	function v
	(
		tag    varchar2,
		value  varchar2,
		switch boolean := null
	) return varchar2 is
	begin
		base(tag, chr(0));
		return sts.lstr || ' value="' || value || '"' || bool_attr(switch) || sts.rstr;
	end;

	procedure v
	(
		tag    varchar2,
		value  varchar2,
		inner  varchar2,
		switch boolean := null
	) is
	begin
		base(tag, inner);
		b.l(sts.lstr || ' value="' || value || '"' || bool_attr(switch) || sts.rstr);
	end;

	function v
	(
		tag    varchar2,
		value  varchar2,
		inner  varchar2,
		switch boolean := null
	) return varchar2 is
	begin
		base(tag, inner);
		return sts.lstr || ' value="' || value || '"' || bool_attr(switch) || sts.rstr;
	end;

	procedure c(comment varchar2) is
	begin
		b.l('<!--' || comment || '-->');
	end;

	procedure d
	(
		unit varchar2,
		line varchar2
	) is
	begin
		b.l('<!--@' || unit || ':' || line || '-->');
	end;

end ztag;
/
