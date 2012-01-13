create or replace function u1(p_url varchar2, p_flag varchar2 := null) return varchar2 is
	v_proc    varchar2(100) := r.prog;
	v_psp_url varchar2(100) := nvl(r.cgi('psp_url'), '/psp');
	function sf(o varchar2, cls varchar2 := 'common') return varchar2 is
	begin
		if k_ccflag.get_ext_fs is null then
			if cls = 'psp' then
				return nvl(r.cgi('psp_url'), '/psp') || '/' || o;
			elsif r.path_compact_level = 'dad' then
				return r.dad || '/' || o;
			else
				return o;
			end if;
		else
			if cls = 'psp' then
				dbms_alert.signal('url', o);
				return k_ccflag.get_ext_fs || nvl(r.cgi('psp_url'), '/psp') || '/common/' || o;
			else
				return k_ccflag.get_ext_fs || '/' || k_dad_adm.get_dad_schema || '/' || cls || '/' || o;
			end if;
		end if;
	end;
begin
	-- self reference, link to 'u:' as to link to self url
	if p_url is null then
		return v_proc || t.nnpre('?', owa_util.get_cgi_env('query_string'));
	end if;

	-- v_dad  := t.tf(v_proc like 'psp%.%', v_psp_url || '/', '../');

	-- deal with specific file
	case p_url
		when 'd.css' then
			return sf(t.tf(v_proc like 'psp%.%', v_psp_url || '/!s/') || 'pub/base.css', 'psp'); -- for dad 
		when 'p.css' then
			return sf(v_psp_url || 'pub/base.css', 'common'); -- for site
		when 'g.css' then
			return sf('portal base.css', 'common'); -- for global
		when 'WdatePicker.js' then
			return sf(v_psp_url || 'pub/import/My97DatePicker/WdatePicker.js', 'psp');
		else
			null;
	end case;

	-- u:proc -> pack.proc
	if instr(p_url, '.') = 0 then
		return regexp_substr(v_proc, '^[^.]+') || '.' || p_url;
	end if;

	-- u:.ext -> pack/proc.ext
	if regexp_like(p_url, '^\.\w+$') then
		return sf(replace(v_proc, '.', '/') || '.' || substr(p_url, 2), 'packs');
	end if;

	-- u:pw/dir/file -> host/psp/common/dir/file
	if p_url like 'pw/%/%.%' then
		return sf(replace(p_url, 'pw/', ''), 'psp');
	end if;

	-- u:pw/xxx.ext -> /psp/!s/pub/ext/xxx.ext
	if p_url like 'pw/%' then
		return sf(regexp_replace(p_url, '^(pw)(.*)/([^./]+)\.([^./]+)$', 'pub/\4\2/\3.\4'), 'psp');
	end if;

	-- u:file.ext -> pack/file.ext
	if instr(p_url, '/') = 0 and instr(p_url, '.') > 0 then
		return sf(regexp_substr(v_proc, '^[^.]+') || '/' || p_url, 'packs');
	end if;

	return sf(p_url);
end u1;
/

