create or replace package body k_file2 is

	function get_folder(p_gw_name varchar2) return varchar2 is
	begin
		return regexp_substr(p_gw_name, '^(F\d+)/(.*)', subexpression => 1);
	end;

	function get_fname(p_gw_name varchar2) return varchar2 deterministic is
	begin
		return regexp_substr(p_gw_name, '^(F\d+)/(.*)', subexpression => 2);
	end;

	function get_name(p_gw_name varchar2) return varchar2 deterministic is
	begin
		return regexp_substr(p_gw_name, '^(F\d+)/(.*)\.(\w+)$', subexpression => 2);
	end;

	function get_suffix(p_gw_name varchar2) return varchar2 deterministic is
	begin
		return regexp_substr(p_gw_name, '^(F\d+)/(\w+)\.(\w+)$', subexpression => 3);
	end;

	function seq_like_patten(p_gw_name varchar2) return varchar2 deterministic is
	begin
		return get_name(p_gw_name) || '%.' || get_suffix(p_gw_name);
	end;

	function seq_extract_patten(p_gw_name varchar2) return varchar2 deterministic is
	begin
		return '^' || get_name(p_gw_name) || '(\d*)\.' || get_suffix(p_gw_name) || '$';
	end;

	function seq_value
	(
		p_gw_name   varchar2,
		p_comp_name varchar2
	) return varchar2 deterministic is
	begin
		return to_number(regexp_substr(p_comp_name, seq_extract_patten(p_gw_name), 1, 1, '', 1));
	end;

	procedure upload
	(
		p_name varchar2,
		p_blob in out nocopy blob
	) is
		p varchar2(100) := '/psp.web/upload/' || r.cgi('dad_name') || '/stage';
		v boolean;
		e exception;
		pragma exception_init(e, -31001);
		pragma autonomous_transaction;
	begin
		<<redo_file>>
		begin
			v := dbms_xdb.createresource(p || '/' || p_name, p_blob);
		exception
			when e then
				v := false;
		end;
		if not v then
			<<redo_folder>>
			begin
				v := dbms_xdb.createfolder(p || '/' || regexp_substr(p_name, '(\w+)/', subexpression => 1));
			exception
				when e then
					v := false;
			end;
			if not v then
				v := dbms_xdb.createfolder(p);
				if v then
					goto redo_folder;
				else
					raise_application_error(-20996, 'cannot create dad''s upload forder/file');
				end if;
			end if;
			goto redo_file;
		end if;
		p_blob := null;
		commit;
	end;

	-- p_path
	procedure ensure_folder(p_path varchar2) is
		v_path   varchar2(4000);
		v_pos    pls_integer := 0;
		v_cnt    pls_integer := 0;
		v_prefix varchar2(100) := '/psp.web/upload/' || r.cgi('dad_name');
		v        boolean;
	begin
		loop
			v_pos := instr(p_path, '/', v_pos + 1, 1);
			exit when v_pos <= 0;
			v_path := substr(p_path, 1, v_pos - 1);
			p.p(v_prefix || v_path);
			if not dbms_xdb.existsresource(v_prefix || v_path) and
				 dbms_xdb.createfolder(v_prefix || v_path) then
				null;
			end if;
		end loop;
		if not dbms_xdb.existsresource(v_prefix || p_path) and
			 dbms_xdb.createfolder(v_prefix || p_path) then
			null;
		end if;
	end;

	procedure place
	(
		p_gw_name varchar2,
		p_path    varchar2,
		p_name    varchar2
	) is
		v_dir varchar2(100) := '/psp.web/upload/' || r.cgi('dad_name');
	begin
		ensure_folder(p_path);
		dbms_xdb.renameresource(v_dir || '/stage/' || p_gw_name, v_dir || p_path, p_name);
		dbms_xdb.deleteresource(v_dir || '/stage/' || get_folder(p_gw_name), dbms_xdb.delete_resource);
	end;

	procedure place
	(
		p_gw_name varchar2,
		p_path    varchar2
	) is
		v_dir varchar2(200) := '/psp.web/upload/' || r.cgi('dad_name');
	begin
		p.split(p_gw_name, '/');
		ensure_folder(p_path || '/' || p.gv_st(1));
		dbms_xdb.renameresource(v_dir || '/stage/' || p_gw_name, v_dir || p_path || '/' || p.gv_st(1),
														p.gv_st(2));
		dbms_xdb.deleteresource(v_dir || '/stage/' || get_folder(p_gw_name), dbms_xdb.delete_resource);
	end;

	procedure download is
		v_str              varchar2(500);
		v_url              xdburitype;
		v_res              xmltype;
		v_modificationdate date;
		v_content_type     varchar2(100);
		v_characterset     varchar2(100);
	begin
		v_str := '/psp.web/upload/' || r.cgi('dad_name') || '/' || r.cgi('path_info');
		dbms_alert.signal('v_str', v_str);
		v_url := xdburitype(v_str);
		-- v_res := v_url.getresource(); -- oracle bug : will cause ora-600 error
		select v_url.getresource() into v_res from dual;
		select to_date(substrb(extractvalue(v_url.getresource(), '/Resource/ModificationDate/text()'), 1,
													 20), 'YYYY-MM-DD"T"HH24:MI:SS.') +
					 nvl(owa_custom.dbms_server_gmtdiff, 8) / 24,
					 extractvalue(v_url.getresource(), '/Resource/ContentType/text()'),
					 extractvalue(v_url.getresource(), '/Resource/CharacterSet/text()')
			into v_modificationdate, v_content_type, v_characterset
			from dual;

		k_http.set_content_type(v_content_type);
		k_http.set_last_modified(v_modificationdate);

		if k_http.get_if_modified_since = v_modificationdate then
			-- ¨¨?1??¨ª?¡ì??cache¦Ì?¨º¡À??¡ä¨¢o¨ªxml-repo?D¦Ì?¨°??¨´¦Ì??¡ã¡ê??¡À?¨®¡¤¦Ì?? 304
			owa_util.status_line(304, bclose_header => true);
		elsif owa_cache.get_etag = to_char(v_modificationdate, 'yyyymmddhh24miss') then
			-- ¨¨?1? plsql gateway cache ¦Ì? etag ¨°???¦Ì??¡ã¡ê??¨°¨º1¨®? gateway cache ?¡ä?¨¦
			owa_cache.set_not_modified;
		else
			wpg_docload.v_blob := v_url.getblob();
			k_http.set_last_modified(v_modificationdate);
			owa_cache.set_cache(to_char(v_modificationdate, 'yyyymmddhh24miss'), owa_cache.system_level);
		end if;

		k_http.dump_cache('X');
	end;

end k_file2;
/

