create or replace package body z is

	/**
  * tmp.vs := st(t.tf(v1), t.tf(v2), v3);
  * <div#id.cls1.-cls2?.cls3-? checked disabled? -isnode? w=4 h=? style="border:1px solid"
  * .
  */

	--private
	/**
  * return lstr, rstr for public API to join lstr||extra||rstr
  * x.p(1) := 'info';
  * x.p(2) := t.tf(v_is_collapse);
  * x.p(3) := t.tf(v_is_disabled);
  * x.p(4) := t.tf(v_is_node);
  * x.p(5) := v_height;
  * x.p(6) := 'click:some_vm_func';
  * <div#id.alert.alert-?.collapse.in? checked disabled? -isnode? width=4 height=? 
     style="border:1px solid" -bind=?>
  */
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
		re   varchar2(10) := '[#. />"]';
		sect varchar2(1000); -- current section
		procedure cut(more pls_integer := 0) is
			pre char(1);
			add boolean;
		begin
			if substrb(tag, pr - 1, 1) = '?' then
				pre := substrb(tag, pr - 2, 1);
				-- a:97 z:122 0:48 9:57
				add := not (ascii(pre) between 97 and 122 or ascii(pre) between 48 and 57);
				idx := idx + 1;
				if add then
					sect := substrb(tag, pl + 1 - more, pr - pl - 2 + more) || p(idx);
				elsif p(idx) = 'true' then
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
				sect := replace(substrb(tag, pl, pr - pl - 1), '=', '="') || p(idx) || '"';
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
		if substrb(tag, pl + 2, 1) = '/' then
			sts.tagn := null;
			sts.lstr := null;
			sts.rstr := substrb(tag, pl + 1);
			return;
		end if;
		if pe = 0 then
			pe := lengthb(tag);
		end if;
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
							ts := ' ';
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
				sts.rstr := '>';
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
		if sts.tagn is not null then
			b.l(sts.lstr || sts.rstr);
		else
			b.l(sts.rstr);
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

end z;
/
