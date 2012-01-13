create or replace function u2(url varchar2) return varchar2 is
	c1  char(1) := substrb(url, 1, 1);
	c2  char(1) := substrb(url, 2, 1);
	pos pls_integer;
	dad varchar2(100);
	ext boolean;
	function out_ref(s varchar2) return varchar2 is
	begin
		return 'xxx';
	end;
	function normal(s varchar2) return varchar2 is
	begin
		null;
	end;
	function file1(pack varchar2, file varchar2) return varchar2 is
	begin
		if ext then
			return 'prefix/' ||(dad || r.dad) || '/packs/' || pack || '/' || file;
		else
			return t.nvl2(dad, '../' || dad || '/') || pack || '/' || file;
		end if;
	end;
begin
	case c1
		when '[' then
			null; -- for external reference
			pos := instrb(url, ']');
			return out_ref(substrb(url, 2, pos - 2)) || substr(url, pos + 1);
		when '.' then
			case c2
				when '/' then
					-- for normal ref
					return normal(substrb(url, 3));
				when '.' then
					-- for other dad's ref, ../dad/xxx
					pos := instrb(url, '/', 4);
					dad := substrb(url, 4, pos - 4);
					return normal(substrb(url, pos + 1));
				else
					-- for .css .js  
					return file1(r.pack, r.proc || url);
			end case;
		when '@' then
			-- for @c @b end case;
			pos := lengthb(r.pack) - 1;
			return normal(substrb(r.pack, 1, pos) || substrb(url, 2));
		when '/' then
			-- for local website ref
			return url;
		when '\' then
			-- for psp.web mount point \dad/xxx
			pos := instrb(url, '/');
			dad := substrb(url, 2, pos - 2);
			return normal(substrb(url, pos + 1));
		else
			if instr(url, '://') > 0 then
				return url; -- absolute url
			elsif instr(url, '/') > 0 then
				-- normal other pack or common reference
				return normal(url);
			elsif instr(url, '.') > 0 then
				-- for file.ext or pack.proc
				return file1(r.pack, r.proc || url);
			elsif substrb(url, -2, 1) = '_' then
				-- link to standalone proc
				return url;
			else
				-- for this pack proc or xxx_b
				return r.pack || '.' || url;
			end if;
	end case;

end u2;
/

