create or replace package body k_hook is

	procedure map_url(p_path varchar2) is
		v_dbcs         varchar2(30) := substr(userenv('LANGUAGE'), instr(userenv('LANGUAGE'), '.') + 1);
		v_rqcs         varchar2(30) := owa_util.get_cgi_env('REQUEST_CHARSET');
		v_xdb_path     varchar2(500);
		v_md5_path     varchar2(32);
		v_attr         varchar2(30);
		v_lmt_cache    varchar2(1000);
		v_lmt_time     date;
		v_xdb_url      xdburitype;
		v_mdate        date;
		v_content_type varchar2(100);
		v_characterset varchar2(100);
		c_fmt constant varchar2(16) := 'yyyymmddhh24miss';
	begin
		if false and k_ccflag.get_ext_fs is not null then
			owa_util.redirect_url(k_ccflag.get_ext_fs || '/' || r.dbu || p_path, false);
			if p_path like '%.appcache' then
				owa_util.mime_header('text/cache-manifest', false);
			end if;
			owa_util.http_header_close;
			return;
		end if;
	
		v_xdb_path  := '/psp.web/static/' || r.dbu || '/' || p_path;
		v_md5_path  := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => p_path)));
		v_attr      := substrb(v_md5_path, 1, 30);
		v_lmt_cache := sys_context('SFLMT', v_attr);
		if v_lmt_cache is not null then
			p.split(v_lmt_cache, ',');
			if p.gv_st(1) = substrb(v_md5_path, 31) then
				v_lmt_time     := to_date(p.gv_st(3), c_fmt);
				v_content_type := p.gv_st(4);
				if k_cache_cfg.instant_gac or sysdate < v_lmt_time + k_cache_cfg.max_age(v_content_type) / 24 / 60 then
					v_mdate := to_date(p.gv_st(2), c_fmt); -- 没到期的话 gac 中的 lmt 有效
				end if;
			else
				v_lmt_cache := null;
			end if;
		end if;
	
		if v_mdate is null or r.cgi('Cache-Control') = 'max-age=0|nonono' then
			v_xdb_url := xdburitype(v_xdb_path);
			-- v_res := v_xdb_url.getresource(); -- oracle bug : will cause ora-600 error
			select to_date(substrb(extractvalue(v_xdb_url.getresource(), '/Resource/ModificationDate/text()'), 1, 20),
										 'YYYY-MM-DD"T"HH24:MI:SS.'),
						 extractvalue(v_xdb_url.getresource(), '/Resource/ContentType/text()')
				into v_mdate, v_content_type
				from dual;
			v_lmt_time := sysdate;
			p.s        := substr(v_md5_path, 31) || ',' || to_char(v_mdate, c_fmt) || ',' || to_char(v_lmt_time, c_fmt) || ',' ||
										v_content_type || ',' || substr(v_xdb_path, 17);
			k_gac.set('SFLMT', v_attr, p.s);
		end if;
	
		owa_cache.init;
		if k_http.get_if_modified_since = v_mdate then
			owa_util.status_line(304, bclose_header => false); -- 如果客户端cache的时间戳和xml-repo中的一样的话，直接返回 304
		elsif owa_cache.get_etag = to_char(v_mdate, c_fmt) then
			owa_cache.set_not_modified; -- 如果 plsql gateway cache 的 etag 一致的话，则使用 gateway cache 即可
		else
			v_xdb_url := nvl(v_xdb_url, xdburitype(v_xdb_path));
			select extractvalue(v_xdb_url.getresource(), '/Resource/ContentType/text()'),
						 extractvalue(v_xdb_url.getresource(), '/Resource/CharacterSet/text()')
				into v_content_type, v_characterset
				from dual;
			k_http.set_content_type(v_content_type);
			k_http.set_last_modified(v_mdate);
			wpg_docload.v_blob := v_xdb_url.getblob();
			if regexp_like(v_content_type, '(text/+.*|.*script.*)') then
				if r.cgi('HTTP_ACCEPT_ENCODING') not like '%gzip%' then
					raise_application_error(-20003, 'Your browser donnot support gzip comression!');
				end if;
				wpg_docload.v_blob := utl_compress.lz_compress(wpg_docload.v_blob, 1);
				htp.p('Content-Encoding: gzip');
			end if;
			owa_cache.set_cache(to_char(v_mdate, c_fmt), owa_cache.system_level);
		end if;
		if p_path like '%.appcache' then
			-- owa_util.mime_header('text/cache-manifest', false);
			k_http.set_content_type('text/cache-manifest');
		end if;
	
		-- k_http.set_max_age(k_cache_cfg.max_age(v_content_type) * 60); -- 不能很好的支持策略
		k_http.set_expire(nvl(k_cache_cfg.safe_time, v_lmt_time + k_cache_cfg.max_age(v_content_type) / 24 / 60));
		k_http.dump_cache; -- 即便是返回 304 或从 cache 中取 header，还是要重新生成 cache header
	exception
		when no_data_found then
			raise_application_error(-20003, 'File cannot be found in xml-db repository!');
	end;

end k_hook;
/

