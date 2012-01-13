create or replace package body k_cache is
	pragma serially_reusable;

	gc_fmt constant varchar2(30) := 'yyyy-mm-dd hh24:mi:ss ';
	gv_force_digest boolean;
	gv_env          varchar2(100);
	gv_path_url     varchar2(4000);
	gv_path_md5     varchar2(32);
	gv_attr         varchar2(30);

	-- req 中缓存的有效期数值
	gv_digest_age  number;
	gv_version_age number;
	gv_env_age     number;

	-- 从当前 gac 中取出的值
	gv_gen_time    date;
	gv_digest_lmt  date;
	gv_digest      varchar2(32);
	gv_version_lmt date; -- 上次更新 gac 只从 vertime 的时间
	gv_vertime     date;
	gv_verscn      number;

	-- 用户自定义版本号相关
	gv_use_vertime boolean; -- 是否使用了 user etag ( version time ) check
	gv_new_vertime date; -- 当前实际计算出的最新的 vertime
	gv_new_verscn  number;
	gv_minor_pass  boolean; -- 是否弱版本检查 ( version time check) 通过了

	gc_chg_attr constant varchar2(100) := 'redo size';
	gv_chg_value number;

	procedure init is
	begin
		null;
	end;

	procedure invalidate(url varchar2, para st := st()) is
		v_path_url varchar2(4000);
		v_path_md5 varchar2(32);
		v_attr     varchar2(30);
	begin
		v_path_url := r.cgi('script_name') || '/!s/' || p.ps(url, para);
		v_path_md5 := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_path_url)));
		v_attr     := substrb(v_path_md5, 1, 30);
		-- dbms_session.clear_identifier;
		k_gac.rm('AETAG', v_attr);
		k_gac.rm('UETAG', v_attr);
	end;

	procedure add_env(p_env varchar2) is
	begin
		if gv_env is null then
			gv_env := p_env;
		else
			gv_env := gv_env || ',' || p_env;
		end if;
	end;

	procedure set_gw_env is
	begin
		gv_env := gw;
	end;

	-- private
	function get_gac(type varchar2) return varchar2 is
		v varchar2(100);
	begin
		if gv_path_url is null then
			gv_path_url := r.cgi('script_name') || r.cgi('path_info') || '?' || r.cgi('query_string') || '#' || gv_env;
			gv_path_md5 := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => gv_path_url)));
			gv_attr     := substrb(gv_path_md5, 1, 30);
		end if;
		-- dbms_session.clear_identifier;
		v := sys_context(type, gv_attr);
		if substrb(v, 1, 2) = substrb(gv_path_md5, 31, 2) then
			return substrb(v, 4);
		else
			return null;
		end if;
	end;

	function need_vertime(p_max_age number := null) return boolean is
		v_gac varchar2(1000);
	begin
		if k_cookie.get('nocache') = 'Y' then
			return false;
		end if;

		-- 先保留供后面 gw_after 采用
		gv_use_vertime := true;
		gv_version_age := p_max_age;

		-- 没有使用任何 server cache，只使用 auto_etag，预先不用做任何事情，在页面生成后执行 gw_after 时再处理
		if gv_env is null then
			return false; -- todo: 可能有问题
		end if;

		-- server cache 必须要设置有效期，以后或者改成如果没有设置有效期则系统自动根据负载自动决定
		if p_max_age is null then
			raise_application_error(-20999, '需要 server etag cache 的时候，肯定要设置 server etag cache 的有效期的');
		end if;

		-- 获取 server cache gac 信息
		v_gac := get_gac('UETAG');
		-- 第一次生成 server cache 或 server cache 被清除，需要计算vertion，而且肯定为假
		-- 如果不计算 version，那么在 auto_digest 后也会记录的，也没有任何问题
		-- 没有必要非得第一次应用 version 时，就要完整的重新生成页面
		if v_gac is null then
			return false;
		end if;

		-- 获取 server cache etag 更新时间和值
		gv_version_lmt := to_date(substr(v_gac, 1, 20), gc_fmt);
		gv_vertime     := to_date(translate(substr(v_gac, 21, 20), '_', ''), gc_fmt);
		gv_verscn      := to_number(substr(v_gac, 41));

		-- server vertime 已经超出有效期，需要重新生成 server cache
		-- todo: 如果已经超过 digest 有效期，则应该返回 true 重算 vertime
		-- 可是自己并不知道 digest 何时过期
		return sysdate > gv_version_lmt + p_max_age / 24 / 60;
	end;

	-- 检查是否通过 user etag 检查，并设置标识; 如果原先没有 vertime，就算检查不通过，那么在auto_etag中也肯定不通过
	procedure check_vertime is
	begin
		-- 没有 version 代表通过，就当负检查还没开始一样
		-- 如果原来没有，现在有了，就代表没通过
		gv_minor_pass := (gv_vertime is null and gv_verscn is null) or
										 (nvl(gv_new_vertime, sysdate + 1) = nvl(gv_vertime, sysdate + 1) and
										 nvl(gv_new_verscn, 0) = nvl(gv_verscn, 0));
		-- 更新 gac 信息
		-- dbms_session.clear_identifier;
		tmp.s := to_char(sysdate, gc_fmt) || nvl(to_char(gv_new_vertime, gc_fmt), lpad('_', 20, '_')) || gv_new_verscn;
		k_gac.set('UETAG', gv_attr, substrb(gv_path_md5, 31, 2) || ' ' || tmp.s);

	end;

	procedure upt_time(p_time date) is
	begin
		if p_time is not null and (gv_new_vertime is null or p_time > gv_new_vertime) then
			gv_new_vertime := p_time;
		end if;
	end;

	procedure upt_scn(p_scn number) is
	begin
		if p_scn is not null and (gv_new_verscn is null or p_scn > gv_new_verscn) then
			gv_new_verscn := p_scn;
		end if;
	end;

	/* 如果需要 server cache etag/content, 则 p_env 填大写 GW
  如果只需要 server cache etag, not content，则 p_env 填写相应的 env
  如果不需要 server cache，而只是客户端单个自己应用本地 cache，则 p_env 填写空
  使用 server cache 的时候，如论是否 cache content，p_max_age 都必须填写，而且同时是服务端和客户端的 expire 设置
  不使用 server cache 的时候，p_max_age 是客户端的 expire 设置  */
	procedure auto_digest(p_max_age number := null) is
		v_gac varchar2(72);
		v_str varchar2(100);
	begin
		if k_cookie.get('nocache') = 'Y' then
			gv_digest_age := 0;
		else
			-- 先保留供后面 gw_after 采用
			gv_digest_age := p_max_age;
		end if;

		-- 没有使用任何 server cache，只使用 auto_etag，预先不用做任何事情，在页面生成后执行 gw_after 时再处理
		if gv_env is null then
			gv_force_digest := true;
			return;
		end if;

		-- server cache 必须要设置有效期，以后或者改成如果没有设置有效期则系统自动根据负载自动决定
		if gv_digest_age is null then
			raise_application_error(-20999, '需要 server etag cache 的时候，肯定要设置 server etag cache 的有效期的');
		end if;

		if gv_use_vertime and not (gv_version_age < gv_digest_age) then
			raise_application_error(-20999, '需要 server etag cache 的时候，若版本号计算有效期必须小于页面digest的有效期');
		end if;

		-- 获取 server cache gac 信息
		v_gac := get_gac('AETAG');

		-- 第一次生成 server cache 或 server cache 被清除，这时需要重新生成页面和 server cache
		if v_gac is null then
			return;
		end if;

		-- 获取 server cache etag 更新时间和值
		v_str         := substrb(v_gac, 1, 20);
		gv_digest_lmt := to_date(v_str, gc_fmt);
		v_str         := substrb(v_gac, 21, 20);
		gv_gen_time   := to_date(v_str, gc_fmt);
		gv_digest     := substrb(v_gac, 41);

		-- 如果之前的 uetag 没通过，那么这里也就肯定通过不了了，因此不必做下面的处理了，但是 gac.aetag 信息必须先取出来
		if gv_minor_pass = false then
			return;
		end if;

		-- server etag 已经超出有效期，需要重新生成 server cache
		if sysdate > gv_digest_lmt + gv_digest_age / 24 / 60 then
			return;
		end if;

		-- server cache etag 依然在有效期内
		if k_http.get_etag = gv_digest then
			owa_util.status_line(304, bclose_header => false); -- 客户端 etag 和有效的 server etag 一致
		elsif gv_env = gw and owa_cache.get_etag is not null then
			owa_cache.set_not_modified; -- 允许使用 gw cache 并且有 gw cache 时
		else
			return; -- 可能 server cache 被清理了或者根本没启用内容的 server cache
		end if;

		-- server cache hit, 更新 max-age，返回用户
		if true then
			k_http.set_max_age(0);
		elsif gv_use_vertime then
			k_http.set_expire(nvl(gv_version_lmt, sysdate) + gv_version_age / 24 / 60);
		else
			k_http.set_expire(gv_digest_lmt + gv_digest_age / 24 / 60);
		end if;
		k_http.dump_cache;
		raise_application_error(-20997, 'feed back'); -- respond_ui, no chance to execute gw_after and dump_cache
	end;

	procedure server_expire(p_max_age number) is
		v_gen boolean := false;
	begin
		if k_cookie.get('nocache') = 'Y' then
			return;
		end if;
		gv_env     := to_char(gv_new_vertime, 'yyyymmddhh24miss') || ',' || gv_new_verscn || ',' || gv_env;
		gv_env_age := p_max_age;
		v_gen      := gv_env is not null and (k_http.get_etag is null or k_http.get_etag != gv_env);
		if not v_gen and sysdate < k_http.get_if_modified_since + p_max_age / 24 / 60 then
			owa_util.status_line(304, bclose_header => true); -- 客户端 etag 和有效的 server etag 一致
			raise_application_error(-20997, 'feed back'); -- respond_ui, no chance to execute gw_after and dump_cache
		end if;
	end;

	procedure gw_after is
		v_digest  varchar2(32);
		v_changed boolean;
	begin
		-- 简单的单客户端 server expire 模型支持
		if gv_env_age is not null then
			k_http.set_etag(gv_env);
			k_http.set_last_modified(sysdate);
			return;
		end if;

		v_digest := rawtohex(dbms_crypto.hash(wpg_docload.v_blob, dbms_crypto.hash_md5));

		-- 当没有使用任何的 server cache 的处理，而是强制计算 digest 比较
		if gv_force_digest and gv_env is null then
			if k_http.get_etag = v_digest then
				owa_util.status_line(304, bclose_header => false);
				dbms_lob.createtemporary(wpg_docload.v_blob, true, dbms_lob.call);
			else
				k_http.set_etag(v_digest);
			end if;
			k_http.set_max_age(nvl(gv_digest_age, 0) * 60);
			return;
		end if;

		-- 若没有路径设置就代表没有使用cache机制，否则清理该标志，防止后面引用
		if gv_path_url is null then
			return;
		end if;

		-- after page gen and gzip compression
		gv_digest := nvl(gv_digest, owa_cache.get_etag); -- 可能是gac清理了，但是其实gw cache中存在

		-- 无条件设置客户端 expire 值，无论是 client hit,server hit,re-gen page
		if true then
			k_http.set_max_age(0);
		elsif gv_use_vertime then
			k_http.set_max_age(nvl(gv_version_age, 0) * 60); -- 如果使用小版本检测，应该使用小版本检测周期
		else
			k_http.set_max_age(nvl(gv_digest_age, 0) * 60);
		end if;

		-- env 不空就一定使用了 gac 记录 digest 相关信息，所以要更新 gac 的 server etag
		v_changed := gv_digest is null or gv_digest != v_digest;
		if v_changed then
			gv_gen_time := sysdate; -- 如果 digest 变了，则更新 last modified time
		elsif gv_gen_time is null then
			gv_gen_time := sysdate; -- 如果 gw cache digest 没变，但是 gac 是被清空的情况
		end if;
		-- dbms_session.clear_identifier;
		tmp.s := to_char(sysdate, gc_fmt) || to_char(gv_gen_time, gc_fmt) || v_digest;
		k_gac.set('AETAG', gv_attr, substrb(gv_path_md5, 31, 2) || ' ' || tmp.s);

		-- 客户端 etag 和最新 etag 一样，直接应用 client cache
		if k_http.get_etag = v_digest then
			owa_util.status_line(304, bclose_header => false);
			dbms_lob.createtemporary(wpg_docload.v_blob, true, dbms_lob.call);
			return;
		end if;

		-- 只要不反悔 304，无论是否使用 gw content cache，都要设置 etag,lmt
		k_http.set_etag(v_digest);
		k_http.set_last_modified(gv_gen_time);

		-- 对于 gw cache，要么更新，要么命中复用
		if gv_env = gw then
			if v_changed or owa_cache.get_etag is null then
				owa_cache.set_cache(v_digest, owa_cache.system_level);
			else
				owa_cache.set_not_modified;
			end if;
		end if;
	end;

	procedure set_nocache(p_max_age number) is
	begin
		k_cookie.set_max_age('nocache', p_max_age);
	end;

	procedure chk_set_nocache is
		v_cnt pls_integer;
	begin
		if false then
			select count(1)
				into v_cnt
				from v$lock a
			 where a.sid = (select b.sid from v$mystat b where rownum = 1)
				 and a.type = 'TM';
		else
			select count(1)
				into v_cnt
				from v$transaction a
			 where a.ses_addr =
						 (select b.saddr from v$session b where b.sid = (select c.sid from v$mystat c where rownum = 1));
		end if;
		dbms_alert.signal('cache', v_cnt);
		if v_cnt > 0 then
			set_nocache(1);
		end if;
	end;

	procedure log_chg_start is
	begin
		select a.value into gv_chg_value from v$mystat a natural join v$statname b where b.name = gc_chg_attr;
	end;
	procedure log_chg_end is
		v number;
	begin
		select a.value into v from v$mystat a natural join v$statname b where b.name = gc_chg_attr;
		if v - gv_chg_value > 0 then
			set_nocache(3);
			dbms_alert.signal('chg', v - gv_chg_value);
		else
			dbms_alert.signal('chg', 'no change discovered');
		end if;
	end;

	procedure log_chg is
		v number;
	begin
		select a.value into v from v$mystat a natural join v$statname b where b.name = gc_chg_attr;
		dbms_alert.signal('chg', v);
	end;

end k_cache;
/

