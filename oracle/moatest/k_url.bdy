create or replace package body k_url is

	-- private
	function outside(key varchar2) return varchar2 is
	begin
		return k_cfg_reader.find_prefix(sys_context('user', 'current_schema'), key);
	end;

	function normalize(url varchar2, proc boolean := true) return varchar2 is
		c1  char(1) := substrb(url, 1, 1);
		c2  char(1) := substrb(url, 2, 1);
		pos pls_integer;
		dad varchar2(100);
		ext varchar2(1000) := k_ccflag.get_ext_fs;
		pwd varchar2(100) := nvl(r.cgi('psp_dad'), 'psp');
	
		function pri_file(file varchar2) return varchar2 is
		begin
			if ext is not null then
				return ext || '/' || nvl(dad, r.dbu) || '/packs/' || nvl(r.pack, r.proc) || '/' || file;
			else
				return t.nvl2(dad, '../' || dad || '/') || 'packs/' || nvl(r.pack, r.proc) || '/' || file;
			end if;
		end;
	
		function normal(s varchar2) return varchar2 is
			pack varchar2(10);
		begin
			if regexp_like(s, '^[^./]+_\w(\.[^./]+)?(\?.*)?$') then
				if s = 'default_b.d' then
					return t.nvl2(dad, '../' || dad, '.');
				else
					return t.nvl2(dad, '../' || dad || '/') || s;
				end if;
			else
				if regexp_like(s, '^[^./]+_\w/.+') then
					pack := 'packs/';
				end if;
				if ext is not null then
					return ext || '/' || nvl(dad, r.dbu) || '/' || pack || s;
				elsif dad is not null or r.dad != r.dbu then
					return '../' || nvl(dad, r.dbu) || '/' || pack || s;
				else
					return pack || s;
				end if;
			end if;
		end;
	
	begin
		case c1
			when '=' then
				-- first judge, if used, often large amount of url
				return substrb(url, 2);
			when '[' then
				-- for external reference
				pos := instrb(url, ']');
				return outside(substrb(url, 2, pos - 2)) || substr(url, pos + 1);
			when '.' then
				case c2
					when '/' then
						-- for normal ref
						return normal(substrb(url, 3));
					when '.' then
						-- for other dad's ref, ../dad/xxx
						pos := instrb(url, '/', 4);
						if pos <= 0 then
							return '../' || r.dad; -- .. only3
						end if;
						dad := substrb(url, 4, pos - 4);
						return normal(substrb(url, pos + 1));
					else
						-- for .css .js  n
						return pri_file(t.nvl2(r.pack, r.proc, 'proc') || url);
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
				if url like 'pw/%' then
					pos := instrb(url, '/', 4);
					if pos <= 0 then
						-- common css,js
						dad := pwd;
						-- u:pw/xxx.ext -> /psp/pub/ext/xxx.ext        
						return normal(regexp_replace(url, '^pw/([^.]+)\.([^.]+)$', 'pub/\2/\1.\2'));
					else
						-- the same as ../psp/...
						dad := pwd;
						return normal(substrb(url, 4));
					end if;
				elsif instr(url, '://') > 0 or url like 'javascript:%' then
					return url; -- absolute url
				elsif instr(url, '/') > 0 then
					-- normal other pack or common reference
					return normal(url);
				elsif instr(url, '.') > 0 then
					-- for file.ext or pack.proc
					if proc then
						return t.tf(url = 'default_b.d', '../' || r.dad, t.tf(r.prog = 'default_b.d', r.dad || '/') || url);
					else
						return pri_file(url);
					end if;
				elsif regexp_like(url, '^[^.?]+_\w(\?.*)?$') then
					-- link to standalone proc
					return url;
				else
					-- for this pack proc or xxx_b
					return r.pack || '.' || url;
				end if;
		end case;
	end;

end k_url;
/

