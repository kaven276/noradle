create or replace function url(lstr varchar2) return varchar2 is

	c1   char(1) := substrb(lstr, 1, 1);
	c2   char(1);
	str  varchar2(32767);
	main varchar2(30);
	pos  pls_integer;

	-- private
	function outside(p_key varchar2) return varchar2 is
		v_prefix ext_url_v.prefix%type;
	begin
		if not r.is_lack('l$' || p_key) then
			return r.getc('l$' || p_key);
		end if;
		select a.prefix
			into v_prefix
			from ext_url_t a
		 where a.dbu = r.dbu
			 and a.key = p_key;
		return v_prefix;
	exception
		when no_data_found then
			return 'http://' || p_key || '.' || r.dbu || '.no_data_found.ext_url_v.com/';
	end;

	function base return varchar2 is
	begin
		return r.getc('l$');
	end;

begin

	if substrb(lstr, -1) = '@' then
		declare
			n varchar2(30);
			m varchar2(30);
		begin
			str := substrb(lstr, 1, lengthb(lstr) - 1);
			while true loop
				n := regexp_substr(str, '{\w+}');
				if n is null then
					exit;
				end if;
				m := substrb(n, 2, lengthb(n) - 2);
				if r.is_lack(m) then
					str := regexp_replace(str, '(\?|&)' || n, '');
				else
					str := replace(str, n, m || '=' || r.getc(m));
				end if;
			end loop;
		end;
	else
		str := lstr;
	end if;

	if substrb(str, -1) in ('?', '&') then
		if r.is_null('l$?') then
			str := substrb(str, 1, lengthb(str) - 1);
		else
			str := str || r.getc('l$?');
		end if;
	end if;

	case c1
		when '=' then
			return substrb(str, 2);
		when '@' then
			-- for @c @b
			main := nvl(r.pack, r.proc);
			main := substrb(main, 1, lengthb(main) - 1);
			c2   := substrb(str, 3, 1);
			if c2 = '.' then
				-- @x.xxx
				return './' || main || substrb(str, 2);
			elsif c2 = '/' then
				-- @x/xxx
				return base || 'packs/' || main || substrb(str, 2);
			else
				-- @x
				return './' || main || substrb(str, 2);
			end if;
		when '[' then
			-- [key]local for external reference
			pos := instrb(str, ']');
			return outside(substrb(str, 2, pos - 2)) || substrb(str, pos + 1);
		when '*' then
			if r.pack is null then
				return base || 'packs/' || r.proc || '/proc' || substrb(str, 2);
			else
				return base || 'packs/' || r.pack || '/' || r.proc || substrb(str, 2);
			end if;
		when '^' then
			return base || substrb(str, 2);
		else
			return str;
	end case;

end;
/
