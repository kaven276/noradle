create or replace function url(str varchar2) return varchar2 is

	c1   char(1) := substrb(str, 1, 1);
	c2   char(1);
	main varchar2(30);
	pos  pls_integer;
	dad  varchar2(100);

	function outside(key varchar2) return varchar2 is
	begin
		return k_cfg.find_prefix(sys_context('user', 'current_schema'), key);
	end;

	function base return varchar2 is
	begin
		return r.getc('y$static');
	end;

begin
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
				return main || substrb(str, 2);
			elsif c2 = '/' then
				-- @x/xxx
				return base || 'packs/' || main || substrb(str, 2);
			else
				raise_application_error(-2000, 'url(' || str || ') is invalid');
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
