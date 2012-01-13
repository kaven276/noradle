create or replace package body k_gw is
	pragma serially_reusable;

	cancel exception;
	pragma exception_init(cancel, -20998);

	respond_ui exception;
	pragma exception_init(respond_ui, -20997);

	assert_ex exception;
	pragma exception_init(assert_ex, -20996);

	no_filter exception;
	pragma exception_init(no_filter, -06550); -- Usually a PL/SQL compilation error.

	procedure feedback is
	begin
		-- p.css_link; not css link
		p.ensure_close;
		cpv.fb_token := s_feedback.nextval;
		cpv.fb_blob  := wpg_docload.v_blob;
		k_gac.set('FB', cpv.fb_token, utl_raw.cast_to_varchar2(cpv.fb_blob));
		wpg_docload.v_blob := null;
		owa_util.redirect_url('./feedback?token=' || cpv.fb_token, true);
		raise_application_error(-20997, 'feed back');
	end;

	-- private
	procedure show_info is
		p_token  number(10) := r.getn('token');
		v_hit_pv boolean := cpv.fb_token is not null and cpv.fb_token = p_token;
	begin
		if k_anti_redo.test then
			return;
		end if;
		if v_hit_pv then
			wpg_docload.v_blob := cpv.fb_blob;
			cpv.fb_token       := null;
			cpv.fb_blob        := null;
			dbms_alert.signal('fb', 'hit pv');
		else
			wpg_docload.v_blob := utl_raw.cast_to_raw(sys_context('FB', p_token, 4000)); -- with this user and this cid
			if wpg_docload.v_blob is not null then
				dbms_alert.signal('fb', 'hit gac');
			else
				if r.cgi('If-None-Match') is not null then
					owa_util.status_line(304, bclose_header => true);
				else
					owa_util.status_line(200, bclose_header => true);
					htp.p('please donnot refresh feedback page!');
					htp.p(sys_context('userenv', 'client_identifier'));
				end if;
				dbms_alert.signal('fb', 'refreshed');
				return;
			end if;
		end if;
	
		owa_util.mime_header('text/html', false, utl_i18n.map_charset(r.cgi('REQUEST_CHARSET')));
		htp.p('ETag:FB:"' || p_token || '"');
		htp.p('Cache-Control: max-age = 600');
		owa_util.http_header_close;
		k_gac.rm('FB', p_token);
	end;

	-- private
	procedure show_css is
		v_id   varchar2(32) := substr(r.cgi('query_string'), 4);
		v_attr varchar2(30) := substr(v_id, 1, 29);
		v_raw  raw(4000);
	begin
		if v_id = r.etag then
			owa_util.status_line(304, bclose_header => true);
			return;
		end if;
	
		if cpv.css_digest = v_id then
			wpg_docload.v_blob := cpv.css_blob;
			dbms_alert.signal('css', 'hit');
		else
			dbms_alert.signal('css', 'lose');
			dbms_lob.createtemporary(wpg_docload.v_blob, true, dbms_lob.call);
			for i in 1 .. 9 loop
				v_raw := utl_raw.cast_to_raw(sys_context('css', v_attr || to_char(i), 4000));
				exit when v_raw is null;
				dbms_lob.writeappend(wpg_docload.v_blob, utl_raw.length(v_raw), v_raw);
			end loop;
		end if;
	
		owa_util.mime_header('text/css', false, utl_i18n.map_charset(r.cgi('REQUEST_CHARSET')));
		htp.p('Expires:Thu, 13 Sat 2012 07:06:51 GMT'); -- never expire
		htp.p('Cache-Control: max-age=8640000'); -- 100天
		htp.p('ETag:"' || v_id || '"');
		if r.cgi('HTTP_ACCEPT_ENCODING') like '%gzip%' then
			htp.p('Content-Encoding: gzip');
		else
			wpg_docload.v_blob := utl_compress.lz_uncompress(wpg_docload.v_blob);
		end if;
		owa_util.http_header_close;
	end;

	-- cancel page 比 quit 多个一个取消后续程序执行的功能
	procedure cancel_page(p_commit boolean := false) is
	begin
		if p_commit then
			commit;
		end if;
		raise cancel;
	end;

	procedure assert(p_info varchar2) is
	begin
		raise_application_error(-20000, p_info);
	end;

	procedure do is
		v_prog varchar2(100) := r.prog;
		v_pass boolean := false;
		v_text varchar2(100);
		package_state_invalid exception;
		pragma exception_init(package_state_invalid, -04061); -- 04061  
		invalid_proc exception;
		pragma exception_init(invalid_proc, -6576);
		v_sql0 varchar2(200);
		v_sql1 varchar2(200);
		v_redo boolean := false;
	begin
	
		-- 检查是否是上传文件，如果是先执行 rollback，回滚到 upload_file_t 的插入
		-- 当然这时 upload_file_t 中的数据已经通过 trigger 放到 xml-db repository 中了
		if r.cgi('REQUEST_METHOD') = 'POST' and r.cgi('HTTP_CONTENT_TYPE') like 'multipart/form-data; boundary=%' then
			rollback;
		end if;
	
		-- 反馈页直接显示，不切面，不缓存，不压缩
		case v_prog
			when 'feedback' then
				show_info;
				return;
			when 'css' then
				show_css;
				return;
			else
				null;
		end case;
	
		<<redo>>
		owa_cache.init;
		p.init; -- srp init, 在 show feedback 前设置好字符集
		k_cache.init; -- srp init
		k_http.init; -- srp init
	
		-- 在 feedback 后再清空
		wpg_docload.v_blob := null;
	
		if not v_redo then
			v_redo := true; -- 确保 anti_redo 只检查一次，否则第一次刚设置上，连续自己再看第二次，肯定判断重了
			if k_anti_redo.test then
				return;
			end if;
		end if;
	
		if v_prog like '%_c.%' then
			k_cache.log_chg_start;
		end if;
	
		-- 拦截器部分
		-- 针对 long-job 页面，在生成前显示进度条，在生成完返回最终结果，
		-- 内容在 xml-db 中，以后可以方便的通过 ftp 批量取出
		begin
			execute immediate 'call k_filter.before()';
			v_pass := true;
		exception
			when package_state_invalid then
				v_sql1 := regexp_replace(dbms_utility.format_error_stack,
																 '^.*ORA-04061:( package (body )?"(\w+\.\w+)" ).*$',
																 'alter package \3 compile \2',
																 modifier => 'n');
				if v_sql0 is not null or v_sql1 = v_sql0 then
					raise; -- 如果上一次重编译的内容和本次相同，就是不起作用，就不要无限循环了，而应报错
				else
					sys.pw.recompile(v_sql1);
					v_sql0 := v_sql1;
					goto redo;
				end if;
			when no_filter or invalid_proc then
				v_pass := true;
			when cancel then
				v_pass := false; -- cancel page or p.go
			when respond_ui then
				goto the_end;
			when others then
				v_pass := false;
				-- 【todo: this should use htp to print 】
				-- owa_util.status_line(404, bclose_header => false);
				p.h('', 'before filter exception!');
				p.lcss('body{font-size:20px;}');
				p.p('You can not access this page yet, see the following info:');
				p.pre_open;
				p.prn(substr(sqlerrm, 12));
				p.line;
				p.prn(dbms_utility.format_error_backtrace);
				p.line;
				p.prn(dbms_utility.format_error_stack);
				p.pre_close;
				p.div_open(id => 'support_info', ac => st('#display:block;'));
				p.p('user: ' || user);
				p.p('current_schema: ' || sys_context('user', 'CURRENT_SCHEMA'));
				p.p('r.dbu =' || r.dbu);
				p.p('r.dad =' || r.dad);
				p.p('r.prog=' || r.prog);
				p.p('r.pack=' || r.pack);
				p.p('r.proc=' || r.proc);
				p.div_close;
				p.a('back to app''s main page', 'u:/');
		end;
	
		-- 主体程序部分
		if v_pass then
			v_text := 'call  ' || r.dbu || '.' || v_prog || '()';
			-- v_text := 'call ' || v_prog || '()';
			-- for monitor purpose, we use the upper than the lower line
			begin
				execute immediate v_text;
			exception
				when cancel then
					-- maybe raised by p.go
					--p.h;
					null;
				when respond_ui then
					goto the_end;
				when package_state_invalid then
					v_sql1 := regexp_replace(dbms_utility.format_error_stack,
																	 '^.*ORA-04061:( package (body )?"(\w+\.\w+)" ).*$',
																	 'alter package \3 compile \2',
																	 modifier => 'n');
					if v_sql0 is not null or v_sql1 = v_sql0 then
						raise; -- 如果上一次重编译的内容和本次相同，就是不起作用，就不要无限循环了，而应报错
					else
						sys.pw.recompile(v_sql1);
						v_sql0 := v_sql1;
						goto redo;
					end if;
				when others then
					v_pass := false;
					-- owa_util.status_line(404, bclose_header => false);
					if v_prog like '%.add' then
						p.h;
						p.p('procedure name can not be "add" or other keywords or reserved word ! please change the name.');
					else
						if true then
							p.h;
							p.p('page exception');
							p.p('login user:' || user);
							p.p('current_schema:' || sys_context('user', 'current_schema'));
							p.p(v_text);
							p.pre_open;
							p.prn(dbms_utility.format_error_backtrace);
							p.line;
							p.line;
							p.prn(dbms_utility.format_error_stack);
							p.pre_close;
							p.a('刷新', 'javascript:window.location.reload();');
						end if;
					end if;
			end;
		end if;
	
		if p.gv_xhtp then
			p.ensure_close;
		end if;
	
		if not v_pass then
			owa_util.status_line(404, bclose_header => false);
			owa_cache.disable;
			k_anti_redo.clear;
			return;
		end if;
	
		if wpg_docload.v_blob is not null then
			if (true or r.cgi('HTTP_ACCEPT_ENCODING') like '%gzip%') and dbms_lob.getlength(wpg_docload.v_blob) > 1000 then
				wpg_docload.v_blob := utl_compress.lz_compress(wpg_docload.v_blob, 1);
				htp.p('Content-Encoding: gzip');
			end if;
			k_cache.gw_after;
		end if;
	
		k_http.dump_cache;
		<<the_end>>
		if v_prog like '%_c.%' or v_prog like '%_h.%' then
			k_cache.log_chg_end;
			k_cache.set_nocache(3);
		end if;
		k_anti_redo.clear;
	exception
		when others then
			k_anti_redo.clear;
			raise;
	end;

	procedure trace(info varchar2) is
	begin
		dbms_pipe.pack_message(info);
		tmp.i := dbms_pipe.send_message('step', 0);
	exception
		when others then
			dbms_pipe.purge('step');
	end;

	procedure trace(info st) is
	begin
		for i in 1 .. info.count loop
			dbms_pipe.pack_message(info(i));
		end loop;
		tmp.i := dbms_pipe.send_message('step', 0);
	exception
		when others then
			dbms_pipe.purge('step');
	end;

end k_gw;
/

