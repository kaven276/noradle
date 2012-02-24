create or replace package body k_xhtp is

	pragma serially_reusable;

	-- in out nocopy
	-- wpg_docload.v_blob

	db_charset varchar2(30);
	--dad_charset varchar2(30);
	gv_convert boolean;

	gc_tag_indent  constant pls_integer := 2;
	gc_headers_len constant pls_integer := 200;
	cs             constant char(1) := '~';
	gv_tagnl    char(1);
	gv_cmpct    boolean;
	gv_1st_lcss boolean;

	gv_wap          boolean := false;
	gv_doc_type     varchar2(20);
	gv_doc_type_str varchar2(200);
	gv_compatible   varchar2(100);
	gv_vml          boolean := false;
	gv_smil         boolean := false;

	gv_sv              varchar2(32000);
	gv_selected_values st;
	gv_form_item_open  boolean;
	gv_readonly        boolean; -- form's readonly default for text/password/textarea
	gv_disabled        boolean; -- form's disable default for select/checkbox/radio

	-- API 输出调整变换相关
	gv              varchar2(32000);
	gv_hv_ex        char(1);
	gv_table_id     varchar2(100);
	gv_tbody_switch pls_integer;
	gv_tbody_rows   pls_integer;
	gc_odd_even constant st := st('pwc_odd', 'pwc_even');
	gv_tbody_cur_switch pls_integer;
	gv_in_tbody         boolean;
	gv_tbody_cur_parity pls_integer;
	gv_auto_input_class boolean := false;
	gv_tab_cols         pls_integer := 3;
	gv_cur_col          pls_integer;

	gv_id      varchar2(100);
	gv_cls     varchar2(100);
	gv_css_tag varchar2(30);

	-- table cfg
	gv_class      st;
	gv_label      st;
	gv_align      st;
	gv_width      st;
	gv_style      st;
	gv_format     st;
	gv_item_count integer;

	-- tree type and state
	gv_level pls_integer := 0;
	gv_type  varchar2(10); -- tree,menu

	-- 配置参数
	$if                  k_ccflag.config_mode = k_ccflag.cm_sys $then

	gv_attr_lowercase    char(1) := k_psp_cfg.get_xxx; -- 属性必须是小写
	gv_tag_auto_indent   char(1) := k_psp_cfg.get_xxx; -- 是否自动缩进
	gv_tag_nesting_check char(1) := k_psp_cfg.get_xxx; -- 是否进行标签嵌套错误检查
	gv_proc_exist        char(1) := k_psp_cfg.get_xxx; --k_psp_cfg.get_cfg_value('proc_exist')

	$elsif               k_ccflag.config_mode = k_ccflag.cm_pck $then

	gv_attr_lowercase    char(1) := 'Y'; -- 属性必须是小写
	gv_tag_auto_indent   char(1) := 'Y'; -- 是否自动缩进
	gv_tag_nesting_check char(1) := 'Y'; -- 是否进行标签嵌套错误检查
	gv_proc_exist        char(1) := 'Y'; --k_psp_cfg.get_cfg_value('proc_exist')

	$elsif               k_ccflag.config_mode = k_ccflag.cm_def $then

	gv_attr_lowercase    char(1) := 'Y'; -- 属性必须是小写
	gv_tag_auto_indent   char(1) := 'Y'; -- 是否自动缩进
	gv_tag_nesting_check char(1) := 'Y'; -- 是否进行标签嵌套错误检查
	gv_proc_exist        char(1) := 'Y'; --k_psp_cfg.get_cfg_value('proc_exist')

	$end

	-- 标签栈
	gv_tag_len pls_integer;
	gv_tags    owa.vc_arr;

	type psecs_t is table of varchar2(32767 byte) index by binary_integer;
	gv_psecs    psecs_t;
	gv_css_cnt  pls_integer;
	gv_bdy_cnt  pls_integer;
	gv_save_pt1 pls_integer;
	gv_save_pt2 pls_integer;
	gv_css_link boolean := false;
	gv_css_size pls_integer;
	-- gc_buf_size  pls_integer := 32767;
	gv_head_over boolean; -- 控制往哪个输出缓冲区输出

	-- 免输出，支持免结束标签输出特性
	gv_need_html_close boolean := false;
	gv_need_body_close boolean := false;

	-- 转换在 body 区输出原本应该在 head 的内容
	gv_in_body boolean := false;

	-- 页面生成中是否出现错误
	gv_has_error boolean := false;

	gv_cur_seq pls_integer := 0;

	type t_part is record(
		
		start_pos pls_integer,
		stop_pos  pls_integer);

	type t_parts is table of t_part index by varchar2(100);

	gv_parts t_parts;

	gv_force_css_cv boolean := false;
	gv_css_prefix   varchar2(10);

	function next_seq return varchar2 is
	begin
		gv_cur_seq := gv_cur_seq + 1;
		return 'pw_' || gv_cur_seq;
	end;

	---------

	procedure format_src is
	begin
		gv_cmpct := false;
	end;

	procedure css_link(start_size pls_integer := 512) is
	begin
		gv_css_link := true;
		gv_css_size := start_size;
	end;

	-- private
	procedure split(p varchar2, sep varchar2 := ',') is
		v_pos pls_integer;
		v_old pls_integer := 0;
		v_cnt pls_integer := 0;
	begin
		gv_st := st();
		loop
			v_pos := instr(p, sep, v_old + 1, 1);
			exit when v_pos = 0 or v_pos is null;
			gv_st.extend;
			v_cnt := v_cnt + 1;
			gv_st(v_cnt) := trim(substr(p, v_old + 1, v_pos - v_old - 1));
			v_old := v_pos;
		end loop;
		gv_st.extend;
		gv_st(v_cnt + 1) := trim(substr(p, v_old + 1));
	end;

	function split4tab(p varchar2, sep varchar2 := ',') return st is
	begin
		split(p, sep);
		return gv_st;
	end;

	procedure join(sep varchar2 := ',') is
	begin
		s := gv_st(1);
		for i in 2 .. gv_st.count loop
			s := s || sep || gv_st(i);
		end loop;
	end;

	procedure split2(pairs varchar2, sep varchar2 := ';:') is
		v_single boolean := length(sep) = 1;
		v_sep1   char(1) := substrb(sep, 1, 1);
		v_count  pls_integer;
		v_pos    pls_integer;
		v_old    pls_integer := 0;
		v_pos2   pls_integer;
		v_sep2   char(1);
	begin
		v_single := length(sep) = 1;
		if not v_single then
			v_sep2 := substr(sep, 2, 1);
		end if;
		gv_texts  := st();
		gv_values := st();
		v_count   := length(regexp_replace(pairs, '[^' || v_sep1 || ']', ''));
		gv_texts.extend(v_count);
		gv_values.extend(v_count);
		for i in 1 .. v_count loop
			v_pos := instr(pairs, v_sep1, v_old + 1, 1);
			gv_texts(i) := substr(pairs, v_old + 1, v_pos - v_old - 1);
			if v_single then
				gv_values(i) := gv_texts(i);
			else
				v_pos2 := instr(gv_texts(i), v_sep2);
				if v_pos2 > 0 then
					gv_values(i) := substr(gv_texts(i), v_pos2 + 1);
					gv_texts(i) := substr(gv_texts(i), 1, v_pos2 - 1);
				else
					gv_values(i) := gv_texts(i);
				end if;
			end if;
			v_old := v_pos;
		end loop;
	end;

	function tf(cond boolean, true_str varchar2, false_str varchar2) return varchar2 is
	begin
		return case when cond then true_str else false_str end;
	end;

	function fill_pairs(cur pairs_t) return number is
		i       pls_integer := 0;
		v_text  varchar2(1000);
		v_value varchar2(1000);
	begin
		gv_texts  := st();
		gv_values := st();
		loop
			fetch cur
				into v_text, v_value;
			exit when cur%notfound;
			gv_texts.extend;
			gv_values.extend;
			i := i + 1;
			gv_texts(i) := v_text;
			gv_values(i) := v_value;
		end loop;
		close cur;
		return i;
	end;

	procedure fill_pairs(cur pairs_t) is
		v_dummy number;
	begin
		v_dummy := fill_pairs(cur);
	end;

	-- private
	function l(p varchar2, to_proc boolean := false) return varchar2 is
		r varchar2(32000);
	begin
		--execute immediate 'begin :r :=u(trim(substr(:p,3))); end;'
		--using out r, p;
	
		if gv_convert and length(p) != lengthb(p) then
			r := utl_url.escape(p, false, dad_charset);
		else
			r := p;
		end if;
	
		if r like 'u:%' then
			return u(trim(substr(r, 3)), to_proc);
		elsif r is not null then
			return u(r, to_proc);
		else
			return '';
		end if;
	end;

	----------------------

	procedure show_page is
		v_amount  integer := dbms_lob.lobmaxsize;
		v_do      integer := 1;
		v_so      integer := 1;
		v_blob    blob;
		v_clob    clob;
		v_langctx integer := 0;
		v_warning integer;
	begin
		wpg_docload.get_download_blob(v_blob);
		dbms_lob.createtemporary(v_clob, true, dbms_lob.call);
		dbms_lob.converttoclob(v_clob,
													 v_blob,
													 amount       => v_amount,
													 dest_offset  => v_do,
													 src_offset   => v_so,
													 blob_csid    => nls_charset_id(dad_charset),
													 lang_context => v_langctx,
													 warning      => v_warning);
		-- htp.prn(v_clob);
		dbms_output.put(v_clob);
	end;

	/*
  procedure range_begin(p_id varchar2) is
  begin
    gv_parts(p_id).start_pos := dbms_lob.getlength(gv_blob);
  end;
  
  procedure range_end(p_id varchar2) is
  begin
    gv_parts(p_id).stop_pos := dbms_lob.getlength(gv_blob);
  end;
  
  procedure range_replace
  (
    id      varchar2,
    pattern varchar2,
    value   varchar2
  ) is
    v_rec     t_part := gv_parts(id);
    v_start   pls_integer := v_rec.start_pos;
    v_stop    pls_integer := v_rec.stop_pos;
    v_raw_bfr raw(32767);
    v_raw_aft raw(32767);
    v_str_bfr varchar2(32000);
    v_str_aft varchar2(32000);
    v_len_bfr pls_integer;
    v_len_aft pls_integer;
  begin
    v_raw_bfr := dbms_lob.substr(gv_blob, v_stop - v_start, v_start + 1);
    v_str_bfr := utl_i18n.raw_to_char(data => v_raw_bfr, src_charset => dad_charset);
    v_len_bfr := lengthb(v_str_bfr);
    v_str_aft := replace(v_str_bfr, pattern, value);
    v_len_aft := length(v_str_aft);
    case
      when v_len_aft > v_len_bfr then
        raise_application_error(-20001, 'replace more than original');
      when v_len_aft < v_len_bfr then
        v_str_aft := rpad(v_str_aft, v_len_bfr, ' ');
      when v_len_aft = v_len_bfr then
        null;
    end case;
    v_raw_aft := utl_i18n.string_to_raw(v_str_aft, dst_charset => dad_charset);
    if utl_raw.length(v_raw_bfr) != utl_raw.length(v_raw_aft) then
      raise_application_error(-20001, 'replaced with no matched length');
    end if;
    dbms_lob.write(gv_blob, v_stop - v_start, v_start + 1, v_raw_aft);
  end;
  */

	procedure save_pointer is
	begin
		gv_save_pt1 := gv_bdy_cnt;
		gv_save_pt2 := lengthb(gv_psecs(gv_bdy_cnt));
	end;

	function appended return boolean is
	begin
		return gv_save_pt1 = gv_bdy_cnt and gv_save_pt2 = lengthb(gv_psecs(gv_bdy_cnt));
	end;

	procedure prn(text varchar2) is
	begin
		if text is null then
			return;
		end if;
		if gv_head_over then
			begin
				gv_psecs(gv_bdy_cnt) := gv_psecs(gv_bdy_cnt) || text;
			exception
				when others then
					gv_bdy_cnt := gv_bdy_cnt + 1;
					gv_psecs(gv_bdy_cnt) := text;
			end;
		else
			gv_psecs(0) := gv_psecs(0) || text;
		end if;
	end;

	procedure prn(text in out nocopy clob) is
	begin
		if text is null then
			return;
		end if;
		if gv_head_over then
			begin
				gv_psecs(gv_bdy_cnt) := gv_psecs(gv_bdy_cnt) || text;
			exception
				when others then
					gv_bdy_cnt := gv_bdy_cnt + 1;
					gv_psecs(gv_bdy_cnt) := text;
			end;
		else
			gv_psecs(0) := gv_psecs(0) || text;
		end if;
	end;

	procedure d(text varchar2) is
	begin
		prn(text);
	end;

	-- private: nocopy version for line, ref only by tpl
	procedure line2(text in out nocopy varchar2) is
	begin
		if gv_head_over then
			begin
				gv_psecs(gv_bdy_cnt) := gv_psecs(gv_bdy_cnt) || text || gv_tagnl;
			exception
				when others then
					gv_bdy_cnt := gv_bdy_cnt + 1;
					gv_psecs(gv_bdy_cnt) := text || gv_tagnl;
			end;
		else
			gv_psecs(0) := gv_psecs(0) || text || gv_tagnl;
		end if;
	end;

	procedure line(text varchar2 := '') is
	begin
		if gv_head_over then
			begin
				gv_psecs(gv_bdy_cnt) := gv_psecs(gv_bdy_cnt) || text || gv_tagnl;
			exception
				when others then
					gv_bdy_cnt := gv_bdy_cnt + 1;
					gv_psecs(gv_bdy_cnt) := text || gv_tagnl;
			end;
		else
			gv_psecs(0) := gv_psecs(0) || text || gv_tagnl;
		end if;
	end;

	procedure l(txt varchar2, var st := null) is
		v   varchar2(32000);
		tag varchar2(30);
		id  varchar2(30);
		cls varchar2(100);
		prp varchar2(1000);
		o   varchar2(1000);
		oth varchar2(1000);
	begin
		if var is not null then
			v := ps(txt, var);
		else
			v := txt;
		end if;
		tag := regexp_substr(v, '<(\w+)', subexpression => 1);
		id  := regexp_substr(v, '<\w+#(\w+)', subexpression => 1);
		cls := regexp_substr(v, '<\w+(#\w+)?\.((\w|\.)+);', subexpression => 2);
		prp := regexp_substr(v, '<[^;]+;([^>]+)>', subexpression => 1);
		prp := regexp_replace(prp, '(^|,|;)(((\w|-)+)(=|:)([^=:,;]+))', ' \3="\6"');
		oth := regexp_substr(v, '>.*');
		o := '<' || tag || case
					 when id is not null then
						' id="' || id || '"'
				 end || case
					 when cls is not null then
						' class="' || replace(cls, '.', ' ') || '"'
				 end || prp || oth;
		line(o);
	end;

	procedure force_css_cv is
	begin
		gv_force_css_cv := true;
	end;

	procedure set_css_prefix(prefix varchar2) is
	begin
		if prefix is not null then
			gv_css_prefix := prefix;
		end if;
	end;

	procedure lcss(text varchar2, cv boolean) is
		v_tag varchar2(200);
		v_pos pls_integer;
		v_pad varchar2(2) := ' ';
	begin
		-- format check
		if gv_1st_lcss then
			v_pad       := gv_tagnl || ' ';
			gv_1st_lcss := false;
		end if;
		if gv_id is not null then
			v_tag := gv_css_tag || '#' || gv_id || ' ';
		else
			v_tag := gv_css_tag || ' ';
		end if;
		v_pos := instr(text, '{');
		css(v_pad || v_tag || regexp_replace(substr(text, 1, v_pos), ',\s*', ', ' || v_tag) ||
				regexp_replace(substr(text, v_pos + 1), chr(10) || '\s+', chr(10) || '  '),
				cv);
	end;

	procedure lcss(text varchar2, vals st, cv boolean) is
	begin
		lcss(ps(text, vals, ch => '$'), cv);
	end;

	procedure lcss_selector(texts varchar2) is
	begin
		split(texts, ',');
		lcss_selector(gv_st);
	end;

	procedure lcss_selector(texts st) is
		v_sel  varchar2(1000);
		v_term char(2) := ' ,';
	begin
		for i in 1 .. texts.count loop
			if i = texts.count then
				v_term := ' {';
			end if;
			if gv_id is not null then
				css(' ' || gv_css_tag || '#' || gv_id || ' ' || texts(i) || v_term);
			else
				css(' ' || gv_css_tag || ' ' || texts(i) || v_term);
			end if;
		end loop;
	end;

	procedure lcss_rule(text varchar2, css_end boolean := false) is
	begin
		css('    ' || text);
		if css_end then
			css(' }');
		end if;
	end;

	-- private
	procedure px(text in out nocopy varchar2) is
		v_str varchar2(10);
		v_val pls_integer;
	begin
		if gv_base_width is null then
			return;
		end if;
		if gv_base_width = gv_css_width and gv_base_width = gv_font_width then
			return;
		end if;
		for i in 1 .. 100 loop
			v_str := regexp_substr(text, '[: ](\d+)px', 1, i, '', 1);
			v_val := to_number(v_str);
			exit when v_val is null;
			if v_val < gv_round_limit then
				if v_str like '0%' then
					v_val := ceil(v_val * gv_font_width / gv_base_width);
				else
					v_val := ceil(v_val * gv_css_width / gv_base_width);
				end if;
			else
				if v_str like '0%' then
					v_val := floor(v_val * gv_font_width / gv_base_width);
				else
					v_val := floor(v_val * gv_css_width / gv_base_width);
				end if;
			end if;
			text := regexp_replace(text, '([: ])\d+px', '\1' || to_char(v_val) || 'px', 1, i);
		end loop;
	end;

	procedure css(text varchar2, cv boolean) is
		v_text varchar2(2000);
		v_pos1 pls_integer;
		v_pos2 pls_integer := 0;
	begin
		v_text := text;
		loop
			v_pos1 := instrb(text, 'url(', v_pos2 + 1);
			exit when v_pos1 <= 0;
			v_pos2 := instrb(v_text, ')', v_pos1 + 4);
			v_text := substrb(v_text, 1, v_pos1 + 3) || u(substrb(v_text, v_pos1 + 4, v_pos2 - v_pos1 - 4)) ||
								substrb(v_text, v_pos2);
		end loop;
		if gv_css_cnt = 0 then
			gv_css_cnt := 1;
			gv_psecs(-1) := '';
		end if;
		if cv or gv_force_css_cv then
			v_text := replace(v_text, '^', gv_css_prefix);
		end if;
		if gv_scale then
			px(v_text);
		end if;
	
		begin
			gv_psecs(-gv_css_cnt) := gv_psecs(-gv_css_cnt) || v_text || gv_tagnl;
		exception
			when others then
				gv_css_cnt := gv_css_cnt + 1;
				gv_psecs(-gv_css_cnt) := v_text || gv_tagnl;
		end;
	end;

	procedure css(text varchar2, vals st, cv boolean) is
	begin
		css(ps(text, vals, ch => '$'), cv);
	end;

	procedure print_cgi_env is
	begin
		for i in 1 .. owa.num_cgi_vars loop
			line(owa.cgi_var_name(i) || ' = ' || htf.escape_sc(owa.cgi_var_val(i)));
		end loop;
	end;

	procedure go(url varchar2, vals st := null, info varchar2 := null) is
		v_para st;
		v_url  varchar2(1000);
	begin
		v_url := l(url, true);
		v_url := t.tf(not regexp_like(v_url, '(http://|/|./|../).*'), './') || v_url;
		if vals is not null then
			v_url := ps(v_url, vals);
		end if;
	
		if info is null then
			-- htp.init; 这里会清除掉 cookie 设置，必须屏蔽
			owa_util.redirect_url(v_url, false);
		else
			h;
			script_open;
			line('window.alert("' || info || '");');
			if url like 'javascript:%' then
				line(substr(url, 12));
			else
				line('window.location.replace("' || v_url || '")');
			end if;
			script_close;
		end if;
		k_gw.cancel_page(true);
	end;

	-- public
	function is_dhc return boolean is
	begin
		return not gv_in_body;
	end;

	procedure assert(cond boolean, info varchar2) is
	begin
		if k_ccflag.xhtml_check_printing then
			if not cond then
				raise_application_error(-20996, info);
				gv_has_error := true;
				line('<noscript>');
				line(info || gv_tagnl);
				line(dbms_utility.format_call_stack);
				line('</noscript>');
			end if;
		end if;
	end;

	-- public
	procedure ensure_close is
		v_err_msg  varchar2(200);
		v_clob     clob;
		v_dest_os  integer := 1;
		v_src_os   integer := 1;
		v_amount   integer := dbms_lob.lobmaxsize;
		v_csid     number := nvl(nls_charset_id(dad_charset), 0);
		v_lang_ctx integer := 0;
		v_warning  integer;
		v_num      number(6);
		procedure add2clob(p_str varchar2) is
			v_str varchar2(100) := p_str;
		begin
			dbms_lob.writeappend(v_clob, length(v_str), v_str);
		end;
	begin
		gv_cmpct := true;
		-- 检查未结束标签
		if gv_tag_nesting_check = 'Y' then
			case nvl(gv_tag_len, 0)
				when 0 then
					null; -- ok;
				when 1 then
					assert(gv_tags(1) = 'html', 'xxx');
				when 2 then
					assert(gv_tags(2) = 'body', '未结束标签不是 body，可能是head未结束');
				else
					for i in 1 .. gv_tag_len loop
						v_err_msg := v_err_msg || nl || gv_tags(i);
					end loop;
					assert(false, '存在未结束标签' || v_err_msg);
			end case;
		end if;
		if gv_tag_len is null then
			raise_application_error(-20000, 'dd');
		end if;
	
		if gv_need_body_close then
			body_close;
		end if;
		if gv_need_html_close then
			html_close;
		end if;
	
		if gv_has_error then
			script_open;
			line('
var k_xhtp = {};
k_xhtp.errors = document.all.tags("noscript");
alert(k_xhtp.errors.length);
for(i=0;i<k_xhtp.errors.length;i++)
	self.alert("k_xhtp error " + i + "\n\n" + k_xhtp.errors(i).innerHTML);
		');
			script_close;
		end if;
	
		-- 输出到 v_blob 中
		dbms_lob.createtemporary(v_clob, true, dbms_lob.call);
		dbms_lob.createtemporary(wpg_docload.v_blob, true, dbms_lob.call);
		if gv_psecs(0) is not null then
			dbms_lob.writeappend(v_clob, length(gv_psecs(0)), gv_psecs(0));
		end if;
		if gv_css_cnt > 0 then
			if gv_css_link and sys_context('CSS', 'clearing', 1) is null and
				 ((gv_css_cnt - 1) * 32767 + lengthb(gv_psecs(-gv_css_cnt))) > gv_css_size then
				declare
					v_css_clob clob;
					v_raw      raw(4000);
					v_attr     varchar2(30);
					v_sects    number(1);
				begin
					dbms_lob.createtemporary(v_css_clob, true, dbms_lob.call);
					dbms_lob.createtemporary(cpv.css_blob, true, dbms_lob.call);
					for i in 1 .. gv_css_cnt loop
						dbms_lob.writeappend(v_css_clob, length(gv_psecs(-i)), gv_psecs(-i));
					end loop;
					v_amount := dbms_lob.lobmaxsize;
					dbms_lob.converttoblob(cpv.css_blob,
																 v_css_clob,
																 v_amount,
																 v_dest_os,
																 v_src_os,
																 v_csid,
																 v_lang_ctx,
																 v_warning);
					cpv.css_blob   := utl_compress.lz_compress(cpv.css_blob, 1);
					cpv.css_digest := rawtohex(dbms_crypto.hash(cpv.css_blob, dbms_crypto.hash_md5));
					v_sects        := ceil(dbms_lob.getlength(cpv.css_blob) / 4000);
					v_attr         := substrb(cpv.css_digest, 1, 29);
					if substrb(sys_context('CSS', v_attr || '0'), 1, 3) = substrb(cpv.css_digest, 30, 3) and false then
						null;
					else
						k_gac.set('CSS',
											v_attr || '0',
											substrb(cpv.css_digest, 30, 3) || v_sects || to_char(sysdate, ' yyyy-mm-dd hh24:mi'));
						for i in 1 .. v_sects loop
							v_amount := 4000;
							dbms_lob.read(cpv.css_blob, v_amount, 4000 * (i - 1) + 1, v_raw);
							k_gac.set('CSS', v_attr || to_char(i), utl_raw.cast_to_varchar2(v_raw));
						end loop;
					end if;
					add2clob('<link href="css?id=' || cpv.css_digest || '" type="text/css" rel="stylesheet"/>' || nl);
				end;
			else
				add2clob(nl || '<style>' || gv_tagnl);
				for i in 1 .. gv_css_cnt loop
					dbms_lob.writeappend(v_clob, length(gv_psecs(-i)), gv_psecs(-i));
				end loop;
				add2clob(gv_tagnl || '</style>');
			end if;
		end if;
		for i in 1 .. gv_bdy_cnt loop
			dbms_lob.writeappend(v_clob, length(gv_psecs(i)), gv_psecs(i));
		end loop;
	
		v_dest_os := 1;
		v_src_os  := 1;
		v_amount  := dbms_lob.lobmaxsize;
		dbms_lob.converttoblob(wpg_docload.v_blob, v_clob, v_amount, v_dest_os, v_src_os, v_csid, v_lang_ctx, v_warning);
	end;

	---------------------------------------------------------------------------

	procedure x0___________ is
	begin
		null;
	end;

	-- 公共 private 过程，嵌套检查和自动缩进支持
	/*
  在欠套检查的同时进行自动缩进；
  ac:tag_len 记录当前嵌套标签的深度，第一个标签是 body，深度是1。
  ac:tag_n 是记录第n层深度的标签。
  只对成对标签进行嵌套检查，对所有标签进行缩进。
  */
	procedure tag_push(tag varchar2) is
	begin
		gv_tag_len := gv_tag_len + 1;
		gv_tags(gv_tag_len) := tag;
	end;

	procedure tag_pop(tag varchar2) is
	begin
		assert(gv_tags(gv_tag_len) = tag, '标签欠套错误：结束标签没有对应的开始标签' || gv_tag_len);
		gv_tags(gv_tag_len) := null;
		gv_tag_len := gv_tag_len - 1;
	end;

	procedure tag_indent is
	begin
		if gv_tag_auto_indent != 'Y' or gv_cmpct then
			return;
		end if;
	
		if gv_doc_type = 'frameset' then
			d(rpad(' ', (gv_tag_len) * gc_tag_indent, chr(32)));
		elsif gv_tag_len > 2 then
			d(rpad(' ', (gv_tag_len - 2) * gc_tag_indent, chr(32)));
		end if;
	end;

	---------------------------------------------------------------------------

	function w(text varchar2) return varchar2 is
	begin
		return regexp_replace(text, '(.)', '<b>\1</b>');
	end;

	function ps(pat varchar2, vals st, url boolean := null, ch char := ':') return varchar2 is
		v_str varchar2(32000) := pat;
		v_chr char(1) := chr(0);
		v_url boolean;
	begin
		for i in 1 .. vals.count loop
			v_str := replace(v_str, ch || i, v_chr || vals(i));
		end loop;
		return replace(v_str, v_chr, '');
	end;

	procedure ps(pat varchar2, vals st, url boolean := null, ch char := ':') is
	begin
		tag_indent;
		line(ps(pat, vals, url, ch));
	end;

	-- private 对某些公共过程进行封装，用于减少代码量，防止拼null串
	function b2c(value boolean) return varchar2 is
	begin
		if value then
			return 'true';
		else
			return null;
		end if;
	end;

	function b2yn(value boolean) return varchar2 is
	begin
		case value
			when true then
				return 'yes';
			when false then
				return 'no';
			else
				return null;
		end case;
	end;

	function get_tag(full_tag varchar2) return varchar2 is
		v_pos pls_integer;
	begin
		v_pos := instrb(full_tag, ' ');
		if v_pos = 0 then
			return full_tag;
		else
			return substrb(full_tag, 1, v_pos - 1);
		end if;
	end;

	------------------

	function tpl(output boolean, name varchar2, text varchar2, ac in st, da st) return varchar2 is
		v_ac  varchar2(32000);
		v_a1  varchar2(32000);
		v_a2  varchar2(32000);
		v_s   varchar2(32000);
		v_pos pls_integer;
	
		m     varchar2(32000);
		v_tag varchar2(30) := get_tag(name);
	begin
		-- head 区内容不会调用此程序，body,frameset(含自身)才会调用此程序
		if mime_type != 'text/plain' then
			assert(instrb(',html,head,body,frameset,frame,hta:application,title,base,meta,link,script,style,',
										',' || v_tag || ',') > 0 or gv_tags(2) = 'body',
						 '本标签' || v_tag || '必须在body中使用');
		end if;
	
		-- parse ac
		if ac is not null then
			v_ac := ac(1);
			for i in 1 .. ac.count - 1 loop
				v_ac := replace(v_ac, '?' || i, ac(1 + i));
			end loop;
			v_pos := instrb(v_ac, ';#', -1) + 1;
			if v_pos > 1 then
				v_a1 := replace(replace(' ' || substrb(v_ac, 1, v_pos - 2), '=', '="'), ';', '" ') || '"';
				v_s  := ' style="' || substrb(v_ac, v_pos + 1) || '"';
			elsif substrb(v_ac, 1, 1) = '#' then
				-- #xxx
				v_a1 := null;
				v_s  := ' style="' || substrb(v_ac, 2) || '"';
			else
				-- xxx
				if substr(v_ac, -1) != ';' then
					raise_application_error(-20000, 'maybe lose ;');
				end if;
				-- name=#sddsf;name2=#dfsdf#css1:dsfds;css2:xcxcv;
				v_a1 := replace(replace(' ' || v_ac, '=', '="'), ';', '" '); -- todo: 多个一个空格
				v_s  := null;
			end if;
		end if;
		if instrb(v_a1, ':') > 0 then
			raise_application_error(-20000, 'attributes must use =, and not :, for [' || v_ac || ']');
		end if;
	
		-- 自由属性部分
		if da is not null then
			for i in 1 .. floor(da.count / 2) loop
				assert(da(i * 2 - 1) = lower(da(i * 2 - 1)), 'xhtml 属性名必须全部是小写:' || da(i * 2 - 1));
				if da(i * 2) is not null then
					v_a2 := v_a2 || ' ' || da(i * 2 - 1) || '="' || da(i * 2) || '"';
				end if;
			end loop;
			if gv_auto_input_class and name = 'input' then
				v_a1 := v_a1 || ' class="' || substr(da(2), 1, 1) || '"';
			end if;
		end if;
	
		case text
			when el_open then
				m := '<' || name || v_a2 || v_a1 || v_s || '>';
			when el_close then
				m := '</' || v_tag || '>';
			else
				if text is null then
					if regexp_like(name, '^(base|meta|br|hr|col|input|img|link|area|param)$') then
						-- |embed|object|frame
						m := '<' || name || v_a2 || v_a1 || v_s || '/>';
					else
						m := '<' || name || v_a2 || v_a1 || v_s || '></' || v_tag || '>';
					end if;
				else
					m := '<' || name || v_a2 || v_a1 || v_s || '>' || text || '</' || v_tag || '>';
				end if;
		end case;
	
		if output then
			case text
				when el_open then
					tag_indent;
					line2(m);
					tag_push(v_tag);
				when el_close then
					tag_pop(v_tag);
					tag_indent;
					line2(m);
				else
					tag_indent;
					line2(m);
			end case;
			return null;
		else
			return m;
		end if;
	
	end;

	function tag(name varchar2, text varchar2, ac st, da st) return varchar2 is
	begin
		return tpl(false, name, text, ac, da);
	end;

	procedure tag(name varchar2, text varchar2, ac st, da st) is
	begin
		gv := tpl(true, name, text, ac, da);
	end;

	procedure tag_open(name varchar2, ac st := null,
										 -- stand for static bound parameters for attributes and inline-styles
										 da st := null
										 -- stand for dynamic bound parameters for attributes
										 ) is
	begin
		gv := tpl(true, name, el_open, ac, da);
	end;

	procedure tag_close(name varchar2) is
	begin
		tag_pop(name);
		tag_indent;
		d('</' || name || '>' || gv_tagnl);
	end;

	---------------------------------------------------------------------------

	procedure x1___________ is
	begin
		null;
	end;

	procedure init is
	begin
		--gv_xhtp     := false;
		db_charset  := k_setting.db_char_set;
		dad_charset := nvl(owa_util.get_cgi_env('REQUEST_CHARSET'), 'UTF8');
		gv_convert  := lower(db_charset) != lower(dad_charset);
		--scn         := null;
		--gv_in_body  := false; -- reset is_dhc to true for not using k_gw
		gv_doc_type := '';
		--mime_type   := '';
		meta_init;
		--gv_auto_input_class := false;
		--gv_force_css_cv     := false;
		--gv_css_prefix       := '';
		--gv_css_link         := false;
	end;

	procedure http_header_close is
		v varchar2(10);
	begin
		if gv_cmpct then
			gv_tagnl := null;
		else
			gv_tagnl := nl;
		end if;
		-- clear http headers
		gv_doc_type  := null;
		gv_in_body   := false;
		gv_head_over := true;
		gv_tag_len   := 0;
		gv_tags.delete;
		gv_css_cnt := 0;
		gv_bdy_cnt := 1;
		gv_psecs.delete;
		gv_psecs(1) := gv_tagnl;
		gv_psecs(0) := '';
		-- gv_has_error := false;
	end;

	procedure doc_type(name varchar2) is
	begin
		-- htp.p('Content-type: text/html' || '; charset=' || utl_i18n.map_charset(dad_charset));
		http_header_close;
		gv_xhtp := true;
	
		case lower(name)
			when '5' then
				gv_doc_type_str := '<!DOCTYPE html>';
			when 'RDFa' then
				gv_doc_type_str := '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">';
			when '1.1' then
				gv_doc_type_str := '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">';
			when 'basic' then
				gv_doc_type_str := '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">';
			when 'transitional' then
				gv_doc_type_str := '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">';
			when 'strict' then
				gv_doc_type_str := '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">';
			when 'frameset' then
				gv_doc_type_str := '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">';
			when 'wap1.1' then
				gv_doc_type_str := '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">';
				gv_wap          := true;
			when 'mobile' then
				gv_doc_type_str := '<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">';
			when 'text' then
				mime_type := 'text/plain';
			when 'js' then
				mime_type := 'application/x-javascript';
			when 'css' then
				mime_type := 'text/css';
			else
				mime_type := name;
		end case;
	
		if mime_type is null then
			gv_head_over := false;
			mime_type    := 'text/html';
			owa_util.mime_header(mime_type, false, utl_i18n.map_charset(dad_charset));
			gv_headers_str := gv_doc_type_str || nl; -- || '<?xml version="1.0"?>' || nl;
			-- must first doctype and then xml prolog, other wise it will be in backcompatible mode
			if k_ccflag.xml_check then
				line(rpad(' ', gc_headers_len, ' '));
			else
				if true or instr(owa_util.get_cgi_env('http_user_agent'), 'AppleWebKit') = 0 then
					--gv_headers_str := '<!DOCTYPE HTML PUBLIC ''-//W3C//DTD HTML 4.01//EN''>';
					--gv_headers_str := '';
					prn(gv_headers_str); -- for vml to function, continue allow doctype and xml declaration.
				end if;
			end if;
		else
			gv_psecs(1) := '';
			gv_doc_type_str := '';
			gv_head_over := true;
			owa_util.mime_header(mime_type, false, utl_i18n.map_charset(dad_charset));
		end if;
		gv_doc_type := name;
	end;

	procedure use_vml is
	begin
		gv_vml := true;
	end;

	procedure set_compatible(value varchar2) is
	begin
		gv_compatible := value;
	end;

	procedure html_open(manifest varchar2 := null) is
	begin
		assert(gv_tag_len is not null, '系统错误，xhtml 文档没有输出第一行的 doc_type 声明');
		tag_push('html');
		if gv_wap then
			line('<wml>');
		else
			d('<html');
			if manifest = 'cache' then
				d(' manifest');
			elsif manifest is not null then
				d(' manifest="' || manifest || '"');
			end if;
			d(' xmlns="http://www.w3.org/1999/xhtml"');
			if gv_vml then
				d(' xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office"');
			end if;
			line('>');
		end if;
		gv_need_html_close := true;
	end;

	procedure html_close is
	begin
		tag_pop('html');
		if not gv_wap then
			line('</html>');
		else
			line('</wml>');
		end if;
		gv_need_html_close := false;
	end;

	procedure head_open is
	begin
		assert(gv_tag_len = 1 and gv_tags(1) = 'html', 'head 没在 html 底下直接出现');
		line('<head>');
		tag_push('head');
	end;

	procedure head_close is
	begin
		line('<meta name="generator" content="PSP.WEB"/>');
		if gv_compatible is not null then
			meta_http_equiv('X-UA-Compatible', gv_compatible);
		end if;
		-- meta_http_equiv('Content-Type', 'text/html;charset=' || utl_i18n.map_charset(dad_charset));
		if gv_vml then
			line('<?import namespace="v" implementation="#default#VML"?>');
			line('<?import namespace="o" implementation="#default#VML"?>');
			line('<style type="text/css">v\:*, o\:* { behavior:url(#default#VML);display:block; }</style>');
		end if;
		gv_head_over := true;
		tag_pop('head');
		line('</head>');
	end;

	procedure body_open(ac st := null) is
	begin
		assert(gv_tag_len = 1 and gv_tags(1) = 'html', 'body 没在 html 底下直接出现');
		gv                 := tpl(true, 'body', el_open, ac, null);
		gv_in_body         := true;
		gv_need_body_close := true;
	end;

	procedure body_close is
	begin
		line;
		tag_close('body');
		gv_need_body_close := false;
		gv_in_body         := false;
	end;

	----------------- head 部分接口 -----------------------------------------------

	procedure x3___________ is
	begin
		null;
	end;

	procedure assert_in_head(tag varchar2) is
	begin
		assert(gv_tag_len = 2 and gv_tags(2) = 'head', tag || ' 只能在 head 区出现');
	end;

	procedure hta(ac st := null, id varchar2 := null, applicationname varchar2 := null, version varchar2 := null,
								caption boolean := null, sysmenu boolean := null, maximizebutton boolean := null,
								minimizebutton boolean := null, contextmenu boolean := null, navigable boolean := null,
								selection boolean := null, showintaskbar boolean := null, singleinstance boolean := null,
								windowstate varchar2 := null, scroll varchar2 := null, icon varchar2 := null, border varchar2 := null,
								borderstyle varchar2 := null, innerborder boolean := null, scrollflat boolean := null) is
	begin
		gv := tpl(true,
							'hta:application',
							null,
							ac,
							st('id',
								 id,
								 'applicationname',
								 applicationname,
								 'version',
								 version,
								 'caption',
								 b2yn(caption),
								 'sysmenu',
								 b2yn(sysmenu),
								 'maximizebutton',
								 b2yn(maximizebutton),
								 'minimizebutton',
								 b2yn(minimizebutton),
								 'contextmenu',
								 b2yn(contextmenu),
								 'navigable',
								 b2yn(navigable),
								 'selection',
								 b2yn(selection),
								 'showintaskbar',
								 b2yn(showintaskbar),
								 'singleinstance',
								 b2yn(singleinstance),
								 'windowstate',
								 windowstate,
								 'scroll',
								 scroll,
								 'icon',
								 icon,
								 'border',
								 border,
								 'borderstyle',
								 borderstyle,
								 'innerborder',
								 b2yn(innerborder),
								 'scrollflat',
								 b2yn(scrollflat)));
	end;

	procedure title(text varchar2) is
	begin
		assert_in_head('title');
		line('<title>' || text || '</title>');
	end;

	procedure title2(text varchar2) is
	begin
		title(text);
	end;

	procedure base(href varchar2 := null, target varchar2 := null) is
		v_href varchar2(1000);
	begin
		assert_in_head('base');
		v_href := nvl(href, r.cgi('SCRIPT_NAME') || '/');
		gv     := tpl(true, 'base', null, null, st('href', l(href), 'target', nvl(target, '_self')));
	end;

	procedure meta_init is
	begin
		assert(gv_doc_type is null, '必须在开始输出文档前执行 p.meta_init' || gv_doc_type);
		gv_st     := st();
		gv_texts  := st();
		gv_values := st();
	end;

	procedure meta(content varchar2, http_equiv varchar2 default null, name varchar2 default null) is
		v_idx pls_integer := gv_st.count + 1;
	begin
		assert(not (http_equiv is not null and name is not null), 'http_equiv和name不能都有');
		assert(http_equiv is null or name is null, 'http_equiv和name不能全空');
		if gv_doc_type is null then
			-- 如果没开始输出 meta,则先保存到数组
			gv_st.extend;
			gv_texts.extend;
			gv_values.extend;
			if http_equiv is not null then
				gv_st(v_idx) := 'http-equiv';
				gv_texts(v_idx) := http_equiv;
				gv_values(v_idx) := content;
			else
				gv_st(v_idx) := 'name';
				gv_texts(v_idx) := name;
				gv_values(v_idx) := content;
			end if;
			return;
		end if;
		assert_in_head('meta');
		gv := tpl(true, 'meta', null, null, st('http-equiv', http_equiv, 'name', name, 'content', content));
	end;

	procedure meta_http_equiv(http_equiv varchar2, content varchar2) is
	begin
		meta(http_equiv => http_equiv, content => content);
	end;

	procedure meta_name(name varchar2, content varchar2) is
	begin
		meta(name => name, content => content);
	end;

	procedure link(href varchar2, ac st := null) is
		v_pos integer := instrb(href, '.', -1, 1);
		v_ext varchar2(10) := '/' || substrb(href, v_pos + 1);
	begin
		if v_ext = '/css' then
			v_ext := '';
		end if;
		gv := tpl(true, 'link', null, ac, st('href', l(href), 'type', 'text/css', 'rel', 'stylesheet' || v_ext));
	end;

	procedure links(hrefs varchar2, ac st := null) is
	begin
		split(hrefs);
		for i in 1 .. gv_st.count loop
			link(gv_st(i) || '.css', ac);
		end loop;
	end;

	procedure style_open(ac st := null) is
	begin
		gv := tpl(true, 'style', el_open, ac, null);
	end;

	procedure style_close is
	begin
		tag_pop('style');
		line('</style>');
	end;

	procedure script_text(text varchar2) is
	begin
		script_open;
		line(text);
		script_close;
	end;

	procedure js(text varchar2) is
	begin
		if gv_tags(gv_tag_len) = 'script' then
			line(text);
		else
			script_open;
			line(text);
			script_close;
		end if;
	end;

	procedure script(src varchar2, ac st := null) is
	begin
		gv := tpl(true, 'script', null, ac, st('src', l(src), 'language', 'JavaScript', 'type', 'text/javascript'));
	end;

	procedure scripts(src varchar2, ac st := null) is
	begin
		split(src);
		for i in 1 .. gv_st.count loop
			script(gv_st(i) || '.js', ac);
		end loop;
	end;

	procedure script_open(ac st := null) is
	begin
		gv := tpl(true, 'script', el_open, ac, st('language', 'JavaScript', 'type', 'text/javascript'));
	end;

	procedure script_close is
	begin
		tag_pop('script');
		line('</script>');
	end;

	-------------------------------

	procedure html_head(title varchar2 default 'psp.web', links st := null, scripts st := null, body boolean default true) is
	begin
		if gv_doc_type is null then
			doc_type;
		end if;
		html_open;
		head_open;
		title2(title);
		base;
		if scripts is not null then
			for i in 1 .. scripts.count loop
				script(src => scripts(i));
			end loop;
		end if;
		if links is not null then
			for i in 1 .. links.count loop
				link(href => links(i));
			end loop;
		end if;
		head_close;
		if body then
			body_open;
		end if;
	end;

	procedure html_tail is
	begin
		body_close;
		html_close;
	end;

	procedure h(files varchar2 := null, title varchar2 default 'psp.web', target varchar2 := null, href varchar2 := null,
							charset varchar2 := null, manifest varchar2 := '') is
		v_file varchar2(32000);
	begin
		if not is_dhc then
			return;
		end if;
		if gv_doc_type is not null and gv_tag_len = 0 then
			null;
		else
			doc_type;
		end if;
		html_open(manifest);
		head_open;
		title2(title);
		base(href, target);
		if charset is not null then
			meta_http_equiv('Content-Type', 'text/xhtml; charset=' || charset);
		else
			-- meta_http_equiv('Content-Type', 'text/xhtml; charset=gb2312');
			null;
		end if;
		if gv_st is not null then
			for i in 1 .. gv_st.count loop
				if gv_st(i) = 'http-equiv' then
					meta_http_equiv(gv_texts(i), gv_values(i));
				elsif gv_st(i) = 'name' then
					meta_name(gv_texts(i), gv_values(i));
				end if;
			end loop;
		end if;
		split(files);
		for i in 1 .. gv_st.count loop
			v_file := gv_st(i);
			if regexp_like(v_file, '*\.(css|less|sass|styl)$') then
				link(v_file);
			elsif regexp_like(v_file, '*\.(js|coffee)$') then
				script(v_file);
			end if;
		end loop;
		head_close;
		body_open;
	end;

	-------------------- body 部分 -------------------------------------------------

	procedure x4___________ is
	
	begin
		null;
	end;

	procedure hn(level pls_integer, text varchar2 := null, ac st := null) is
	begin
		assert(level between 1 and 6, 'hn 的级别必须在 1 到 6 之间');
		gv := tpl(true, 'h' || level, text, ac, null);
	end;

	procedure p(text varchar2 := null, ac st := null) is
	begin
		gv := tpl(true, 'p', text, ac, null);
	end;

	procedure pre_open(ac st := null) is
	begin
		gv := tpl(true, 'pre', el_open, ac, null);
	end;

	procedure pre_close is
	begin
		tag_close('pre');
	end;

	procedure div_open(ac st := null, id varchar2 := null) is
	begin
		gv          := tpl(true, 'div', el_open, ac, st('id', id));
		gv_id       := id;
		gv_css_tag  := 'div';
		gv_1st_lcss := true;
	end;

	procedure div_close is
	begin
		tag_close('div');
		gv_id      := null;
		gv_css_tag := null;
	end;

	procedure marquee_open(ac st := null, direction varchar2 := null, behavior varchar2 := null,
												 scrollamount pls_integer := null, scrolldelay pls_integer := null) is
	begin
		gv := tpl(true,
							'marquee',
							el_open,
							ac,
							st('direction', direction, 'behavior', behavior, 'scrollamount', scrollamount, 'scrolldelay', scrolldelay));
	end;

	procedure marquee_close is
	begin
		tag_close('marquee');
	end;

	function span(text varchar2 := null, ac st := null, title varchar2 := null) return varchar2 is
	begin
		return tpl(false, 'span', text, ac, st('title', title));
	end;

	procedure span(text varchar2 := null, ac st := null, title varchar2 := null, class varchar2 := null) is
	begin
		gv := tpl(true, 'span', text, ac, st('title', title, 'class', class));
	end;

	function b(text varchar2 := null, ac st := null, title varchar2 := null) return varchar2 is
	begin
		return tpl(false, 'b', text, ac, st('title', title));
	end;

	procedure b(text varchar2 := null, ac st := null, title varchar2 := null, class varchar2 := null) is
	begin
		gv := tpl(true, 'b', text, ac, st('title', title, 'class', class));
	end;

	--------------------------------------------------------------------------------

	procedure fieldset_open(ac st := null, id varchar2 := null) is
	begin
		gv          := tpl(true, 'fieldset', el_open, ac, st('id', id));
		gv_id       := id;
		gv_css_tag  := 'fieldset';
		gv_1st_lcss := true;
	end;

	procedure fieldset_close is
	begin
		tag_close('fieldset');
	end;

	procedure legend(text varchar2, ac st := null, title varchar2 := null) is
	begin
		gv := tpl(true, 'legend', text, ac, st('title', title));
	end;

	--------------------------------------------------------------------------------

	procedure x5___________ is
	
	begin
		null;
	end;

	procedure table_open(rules varchar2 := null, hv_ex char := null, cellspacing varchar2 := null,
											 cellpadding varchar2 := null, ac st := null, id varchar2 := null, switch_ex pls_integer := null,
											 cols_ex pls_integer := null) is
	begin
		gv_hv_ex            := upper(substr(hv_ex, 1, 1));
		gv_tbody_switch     := switch_ex;
		gv_in_tbody         := false;
		gv_tbody_cur_parity := 1;
		gv_table_id         := id;
		gv_id               := id;
		gv_css_tag          := 'table';
		gv_1st_lcss         := true;
		gv_tab_cols         := cols_ex;
		gv_cur_col          := 0;
		gv                  := tpl(true,
															 'table',
															 el_open,
															 ac,
															 st('rules', rules, 'cellspacing', cellspacing, 'cellpadding', cellpadding, 'id', id));
	end;

	procedure table_close is
	begin
		if gv_tab_cols is not null and gv_cur_col != 0 then
			for i in 1 .. gv_tab_cols - gv_cur_col loop
				td('&nbsp;');
			end loop;
			-- tr_close;
		end if;
		tag_close('table');
		gv_hv_ex    := null;
		gv_table_id := null;
		gv_id       := null;
		gv_css_tag  := null;
	end;

	procedure caption(text varchar2, ac st := null, title varchar2 := null) is
	begin
		gv := tpl(true, 'caption', text, ac, st('title', title));
	end;

	procedure col(class varchar2 := null, align varchar2 := null, width varchar2 := null, span pls_integer := null,
								ac st := null) is
	begin
		gv := tpl(true, 'col', null, ac, st('class', class, 'align', align, 'width', width, 'span', span));
	end;

	procedure cols(classes st) is
	begin
		tag_indent;
		for i in 1 .. classes.count loop
			d('<col class="' || classes(i) || '"/>');
		end loop;
		line;
	end;

	procedure cols(classes varchar2, sep varchar2 := ',') is
	begin
		tag_indent;
		line('<col class="' || replace(classes, sep, '"/><col class="') || '"/>');
	end;

	procedure colgroup(class varchar2 := null, align varchar2 := null, width varchar2 := null, span pls_integer := null,
										 ac st := null) is
	begin
		gv := tpl(true, 'colgroup', null, ac, st('class', class, 'align', align, 'width', width, 'span', span));
	end;

	procedure colgroup_open(class varchar2 := null, align varchar2 := null, width varchar2 := null,
													span pls_integer := null, ac st := null) is
	begin
		gv := tpl(true, 'colgroup', el_open, ac, st('class', class, 'align', align, 'width', width, 'span', span));
	end;

	procedure colgroup_close is
	begin
		tag_close('colgroup');
	end;

	procedure thead_open is
	begin
		gv := tpl(true, 'thead', el_open, null, null);
	end;

	procedure thead_close is
	begin
		tag_close('thead');
	end;

	procedure tbody_open(ac st := null, title varchar2 := null, class varchar2 := null) is
		v_class varchar2(1000) := class || ' ' || gc_odd_even(gv_tbody_cur_parity);
	begin
		gv_in_tbody         := true;
		gv_tbody_rows       := 0;
		gv_tbody_cur_switch := 1;
		gv                  := tpl(true, 'tbody', el_open, ac, st('title', title, 'class', v_class));
		gv_tbody_cur_parity := 3 - gv_tbody_cur_parity;
	end;

	procedure tbody_close is
	begin
		gv_in_tbody := false;
		tag_close('tbody');
	end;

	procedure tfoot_open is
	begin
		gv := tpl(true, 'tfoot', el_open, null, null);
	end;

	procedure tfoot_close is
	begin
		tag_close('tfoot');
	end;

	-- private
	procedure tsect_tr_td_open(tag varchar2, colspan number := null) is
		v_colspan pls_integer;
	begin
		tag_indent;
		if colspan is null then
			if gv_hv_ex = 'H' then
				v_colspan := 2;
			elsif gv_hv_ex = 'V' then
				v_colspan := 1;
			else
				v_colspan := 1;
			end if;
		else
			v_colspan := colspan;
		end if;
		line(ps('<:1><tr><td align="center" colspan=":2">', st(tag, v_colspan)));
		tag_push(tag || '_tr_td');
	end;

	procedure tsect_tr_td_close(tag varchar2) is
	begin
		tag_pop(tag || '_tr_td');
		tag_indent;
		line('</td></tr></' || tag || '>');
	end;

	procedure thead_tr_td_open(colspan number := null) is
	begin
		tsect_tr_td_open('thead', colspan);
	end;

	procedure thead_tr_td_close is
	begin
		tsect_tr_td_close('thead');
	end;

	procedure tbody_tr_td_open(colspan number := null) is
	begin
		tsect_tr_td_open('tbody', colspan);
	end;

	procedure tbody_tr_td_close is
	begin
		tsect_tr_td_close('tbody');
	end;

	procedure tfoot_tr_td_open(colspan number := null) is
	begin
		tsect_tr_td_open('tfoot', colspan);
	end;

	procedure tfoot_tr_td_close is
	begin
		tsect_tr_td_close('tfoot');
	end;

	procedure table_tr_td_open is
	begin
		tag_indent;
		line('<table class="pw_shrink"><tr><td>');
		tag_push('table_tr_td');
	end;

	procedure table_tr_td_close is
	begin
		tag_pop('table_tr_td');
		tag_indent;
		line('</td></tr></table>');
	end;

	-- private
	function tr_switch return varchar2 is
	begin
		if gv_in_tbody and gv_tbody_switch is not null then
			gv_tbody_rows := gv_tbody_rows + 1;
			if gv_tbody_rows = gv_tbody_switch + 1 then
				gv_tbody_rows       := 1;
				gv_tbody_cur_switch := 3 - gv_tbody_cur_switch;
			end if;
			return gc_odd_even(gv_tbody_cur_switch);
		else
			return '';
		end if;
	end;

	procedure tr_open(ac st := null, class varchar2 := null) is
	begin
		gv := tpl(true, 'tr', el_open, ac, st('class', class || ' ' || tr_switch));
	end;

	procedure tr_close is
	begin
		tag_close('tr');
	end;

	procedure tr(text varchar2, ac st := null, class varchar2 := null) is
	begin
		gv := tpl(true, 'tr', text, ac, st('class', class || ' ' || tr_switch));
	end;

	function tr(text varchar2, ac st := null) return varchar2 is
	begin
		return tpl(false, 'tr', text, ac, null);
	end;

	procedure td(text varchar2, ac st := null, title varchar2 := null, colspan pls_integer := null,
							 rowspan pls_integer := null, class varchar2 := null) is
	
	begin
		if gv_tab_cols is not null and text != el_close then
			if gv_cur_col = 0 then
				tr_open;
			end if;
			gv_cur_col := gv_cur_col + 1;
		end if;
	
		gv := tpl(true, 'td', text, ac, st('title', title, 'colspan', colspan, 'rowspan', rowspan, 'class', class));
	
		if gv_tab_cols is not null and text != el_open then
			if gv_cur_col = gv_tab_cols then
				tr_close;
				gv_cur_col := 0;
			end if;
		end if;
	end;

	function td(text varchar2, ac st := null, title varchar2 := null, colspan pls_integer := null,
							rowspan pls_integer := null, class varchar2 := null) return varchar2 is
	begin
		return tpl(false, 'td', text, ac, st('title', title, 'colspan', colspan, 'rowspan', rowspan, 'class', class));
	end;

	procedure th(text varchar2, ac st := null, title varchar2 := null, colspan pls_integer := null,
							 rowspan pls_integer := null, class varchar2 := null) is
	begin
		gv := tpl(true, 'th', text, ac, st('title', title, 'colspan', colspan, 'rowspan', rowspan, 'class', class));
	end;

	function th(text varchar2, ac st := null, title varchar2 := null, colspan pls_integer := null,
							rowspan pls_integer := null, class varchar2 := null) return varchar2 is
	begin
		return tpl(false, 'th', text, ac, st('title', title, 'colspan', colspan, 'rowspan', rowspan, 'class', class));
	end;

	procedure ths(texts st) is
	begin
		tag_indent;
		for i in 1 .. texts.count loop
			d('<th>' || texts(i) || '</th>');
		end loop;
		line;
	end;

	procedure tds(texts st) is
	begin
		tag_indent;
		for i in 1 .. texts.count loop
			d('<td>' || texts(i) || '</td>');
		end loop;
		line;
	end;

	procedure ths(texts varchar2, sep varchar2 := ',') is
	begin
		tag_indent;
		line('<th>' || replace(texts, sep, '</th><th>') || '</th>');
	end;

	procedure tds(texts varchar2, sep varchar2 := ',') is
	begin
		tag_indent;
		line('<td>' || replace(texts, sep, '</td><td>') || '</td>');
	end;

	function ths(texts st) return varchar2 is
		v_rtn varchar2(32000);
	begin
		for i in 1 .. texts.count loop
			v_rtn := v_rtn || '<th>' || texts(i) || '</th>';
		end loop;
		return v_rtn;
	end;

	function tds(texts st) return varchar2 is
		v_rtn varchar2(32000);
	begin
		for i in 1 .. texts.count loop
			v_rtn := v_rtn || '<td>' || texts(i) || '</td>';
		end loop;
		return v_rtn;
	end;

	function ths(texts varchar2, sep varchar2 := ',') return varchar2 is
	begin
		return('<th>' || replace(texts, sep, '</th><th>') || '</th>');
	end;

	function tds(texts varchar2, sep varchar2 := ',') return varchar2 is
	begin
		return('<td>' || replace(texts, sep, '</td><td>') || '</td>');
	end;

	procedure pair(left varchar2, right varchar2) is
	begin
		tr_open;
		th(left);
		td(right);
		tr_close;
	end;

	--------------------------------------------------------------------------------

	procedure x6___________ is
	
	begin
		null;
	end;

	procedure form_open(name varchar2 := null, action varchar2 := null, target varchar2 := null, ac st := null,
											method varchar2 := null, enctype varchar2 := null, readonly_ex boolean := null,
											disabled_ex boolean := null, id varchar2 := null) is
		v_method varchar2(10);
		v_action varchar2(1000);
	begin
		if method is null then
			if target like '%_b.%' then
				v_method := 'get';
			elsif target like '%_c.%' then
				v_method := 'post';
			end if;
		else
			v_method := method;
		end if;
		gv_readonly := readonly_ex;
		gv_disabled := disabled_ex;
		v_action    := l(action, true);
		gv          := tpl(true,
											 'form',
											 el_open,
											 ac,
											 st('name',
													name,
													'action',
													v_action,
													'method',
													v_method,
													'target',
													target,
													'enctype',
													enctype,
													'id',
													id));
		if v_action = '!server' then
			input_hidden('program', l(substr(action, 1, length(action) - 1)));
		end if;
		gv_id       := id;
		gv_css_tag  := 'form';
		gv_1st_lcss := true;
	end;

	procedure form_close is
	begin
		gv_readonly := null;
		gv_disabled := null;
		tag_close('form');
	end;

	-- private
	procedure form_item_open(label_ex varchar2, item_id varchar2 := null, title varchar2 := null) is
	begin
		if label_ex is not null then
			if gv_hv_ex = 'H' then
				tr_open;
				th(label(label_ex, forp => item_id, title => title));
				td(el_open);
			elsif gv_hv_ex = 'V' then
				tr(th(label(label_ex, forp => item_id, title => title)));
				tr_open;
				td(el_open);
			elsif gv_hv_ex is null then
				label(label_ex, forp => item_id, title => title);
			end if;
			gv_form_item_open := true;
		end if;
	end;

	-- private
	procedure form_item_close is
	begin
		if gv_form_item_open then
			if gv_hv_ex is not null then
				td(el_close);
				tr_close;
			end if;
			gv_form_item_open := false;
		end if;
	end;

	procedure label(text varchar2, ac st := null, title varchar2 := null, forp varchar2 := null) is
	begin
		gv := tpl(true, 'label', text, ac, st('title', title, 'for', forp));
	end;

	function label(text varchar2, ac st := null, title varchar2 := null, forp varchar2 := null) return varchar2 is
	begin
		return tpl(false, 'label', text, ac, st('title', title, 'for', forp));
	end;

	procedure label_open(ac st := null, title varchar2 := null, forp varchar2 := null) is
	begin
		gv := tpl(true, 'label', el_open, ac, st('title', title, 'for', forp));
	end;

	procedure label_close is
	begin
		tag_close('label');
	end;

	procedure auto_input_class(flag boolean := true) is
	begin
		gv_auto_input_class := flag;
	end;

	function input_checkbox(name varchar2 := null, value varchar2 := null, checked boolean := false, ac st := null,
													title varchar2 := null, disabled boolean := null) return varchar2 is
	begin
		return tpl(false,
							 'input',
							 null,
							 ac,
							 st('type',
									'checkbox',
									'name',
									name,
									'value',
									value,
									'title',
									title,
									'checked',
									b2c(checked),
									'disabled',
									b2c(nvl(disabled, gv_disabled))));
	end;

	procedure input_checkbox(name varchar2 := null, value varchar2 := null, label_ex varchar2 := null,
													 checked boolean := false, ac st := null, title varchar2 := null, disabled boolean := null) is
	begin
		form_item_open(label_ex, null);
		gv := tpl(true,
							'input',
							null,
							ac,
							st('type',
								 'checkbox',
								 'name',
								 name,
								 'value',
								 value,
								 'title',
								 title,
								 'checked',
								 b2c(checked),
								 'disabled',
								 b2c(nvl(disabled, gv_disabled))));
		form_item_close;
	end;

	function input_radio(name varchar2 := null, value varchar2 := null, checked boolean := false, ac st := null,
											 title varchar2 := null, disabled boolean := null) return varchar2 is
	begin
		return tpl(false,
							 'input',
							 null,
							 ac,
							 st('type',
									'radio',
									'name',
									name,
									'value',
									value,
									'title',
									title,
									'checked',
									b2c(checked),
									'disabled',
									b2c(nvl(disabled, gv_disabled))));
	end;

	procedure input_radio(name varchar2 := null, value varchar2 := null, label_ex varchar2 := null,
												checked boolean := false, ac st := null, title varchar2 := null, disabled boolean := null) is
	begin
		form_item_open(label_ex);
		gv := tpl(true,
							'input',
							null,
							ac,
							st('type',
								 'radio',
								 'name',
								 name,
								 'value',
								 value,
								 'title',
								 title,
								 'checked',
								 b2c(checked),
								 'disabled',
								 b2c(nvl(disabled, gv_disabled))));
		form_item_close;
	end;

	procedure input_hidden(name varchar2 := null, value varchar2 := null, ac st := null) is
	begin
		gv := tpl(true, 'input', null, ac, st('type', 'hidden', 'name', name, 'value', value));
	end;

	procedure input_keep(name varchar2) is
	begin
		input_hidden(name, r.getc(name));
	end;

	procedure input_keeps(name varchar2) is
		v st;
	begin
		r.gets(name, v);
		for i in 1 .. v.count loop
			input_hidden(name, v(i));
		end loop;
	end;

	procedure input_keep_all is
	begin
		for i in 1 .. r.na.count loop
			input_hidden(r.na(i), r.va(i));
		end loop;
	end;

	function input_file(name varchar2 := null, ac st := null, title varchar2 := null, sizep pls_integer := null,
											disabled boolean := null) return varchar2 is
	begin
		return tpl(false,
							 'input',
							 null,
							 ac,
							 st('type',
									'file',
									'name',
									name,
									'title',
									title,
									'size',
									sizep,
									'disabled',
									b2c(coalesce(disabled, gv_disabled, gv_readonly))));
	end;

	procedure input_file(name varchar2 := null, label_ex varchar2 := null, ac st := null, title varchar2 := null,
											 sizep pls_integer := null, disabled boolean := null) is
	begin
		form_item_open(label_ex, null);
		gv := tpl(true,
							'input',
							null,
							ac,
							st('type',
								 'file',
								 'name',
								 name,
								 'title',
								 title,
								 'size',
								 sizep,
								 'readonly',
								 b2c(coalesce(disabled, gv_disabled, gv_readonly))));
		form_item_close;
	end;

	function input_password(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
													sizep pls_integer := null, maxlength pls_integer := null, readonly boolean := null,
													disabled boolean := null) return varchar2 is
	begin
		return tpl(false,
							 'input',
							 null,
							 ac,
							 st('type',
									'password',
									'name',
									name,
									'value',
									value,
									'title',
									title,
									'size',
									sizep,
									'maxlength',
									maxlength,
									'readonly',
									b2c(nvl(readonly, gv_readonly)),
									'disabled',
									b2c(disabled)));
	end;

	procedure input_password(name varchar2 := null, value varchar2 := null, label_ex varchar2 := null, ac st := null,
													 title varchar2 := null, sizep pls_integer := null, maxlength pls_integer := null,
													 readonly boolean := null, disabled boolean := null) is
	begin
		form_item_open(label_ex, null);
		gv := tpl(true,
							'input',
							null,
							ac,
							st('type',
								 'password',
								 'name',
								 name,
								 'value',
								 value,
								 'title',
								 title,
								 'size',
								 sizep,
								 'maxlength',
								 maxlength,
								 'readonly',
								 b2c(nvl(readonly, gv_readonly)),
								 'disabled',
								 b2c(disabled)));
		form_item_close;
	end;

	function input_text(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
											sizep pls_integer := null, maxlength pls_integer := null, readonly boolean := null,
											disabled boolean := null) return varchar2 is
	begin
		return tpl(false,
							 'input',
							 null,
							 ac,
							 st('type',
									'text',
									'name',
									name,
									'value',
									value,
									'title',
									title,
									'size',
									sizep,
									'maxlength',
									maxlength,
									'readonly',
									b2c(nvl(readonly, gv_readonly)),
									'disabled',
									b2c(disabled)));
	end;

	procedure input_text(name varchar2 := null, value varchar2 := null, label_ex varchar2 := null, ac st := null,
											 title varchar2 := null, sizep pls_integer := null, maxlength pls_integer := null,
											 readonly boolean := null, disabled boolean := null) is
	begin
		form_item_open(label_ex, null);
		gv := tpl(true,
							'input',
							null,
							ac,
							st('type',
								 'text',
								 'name',
								 name,
								 'value',
								 value,
								 'title',
								 title,
								 'size',
								 sizep,
								 'maxlength',
								 maxlength,
								 'readonly',
								 b2c(nvl(readonly, gv_readonly)),
								 'disabled',
								 b2c(disabled)));
		form_item_close;
	end;

	function textarea(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
										rows pls_integer := null, cols pls_integer := null, readonly boolean := null,
										disabled boolean := null) return varchar2 is
	begin
		return tpl(false,
							 'textarea',
							 value,
							 ac,
							 st('name',
									name,
									'title',
									title,
									'rows',
									rows,
									'cols',
									cols,
									'readonly',
									b2c(nvl(readonly, gv_readonly)),
									'disabled',
									b2c(disabled)));
	end;

	procedure textarea(name varchar2 := null, value varchar2 := null, label_ex varchar2 := null, ac st := null,
										 title varchar2 := null, rows pls_integer := null, cols pls_integer := null,
										 readonly boolean := null, disabled boolean := null) is
	begin
		form_item_open(label_ex, null);
		gv := tpl(true,
							'textarea',
							value,
							ac,
							st('name',
								 name,
								 'title',
								 title,
								 'rows',
								 rows,
								 'cols',
								 cols,
								 'readonly',
								 b2c(nvl(readonly, gv_readonly)),
								 'disabled',
								 b2c(disabled)));
		form_item_close;
	end;

	procedure button(name varchar2, value varchar2, text varchar2, ac st := null, title varchar2 := null,
									 disabled boolean := null) is
	begin
		gv := tpl(true, 'button', text, ac, st('name', name, 'value', value, 'title', title, 'disabled', b2c(disabled)));
	end;

	function input_button(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
												disabled boolean := null) return varchar2 is
	begin
		return tpl(false,
							 'input',
							 null,
							 ac,
							 st('type',
									'button',
									'name',
									name,
									'value',
									value,
									'title',
									title,
									'disabled',
									b2c(nvl(disabled, gv_disabled))));
	end;

	procedure input_button(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
												 disabled boolean := null) is
	begin
		gv := tpl(true,
							'input',
							null,
							ac,
							st('type',
								 'button',
								 'name',
								 name,
								 'value',
								 value,
								 'title',
								 title,
								 'disabled',
								 b2c(nvl(disabled, gv_disabled))));
	end;

	function input_submit(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
												disabled boolean := null) return varchar2 is
	begin
		return tpl(false,
							 'input',
							 null,
							 ac,
							 st('type',
									'submit',
									'name',
									name,
									'value',
									value,
									'title',
									title,
									'disabled',
									b2c(nvl(disabled, gv_disabled))));
	end;

	procedure input_submit(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
												 disabled boolean := null) is
	begin
		gv := tpl(true,
							'input',
							null,
							ac,
							st('type',
								 'submit',
								 'name',
								 name,
								 'value',
								 value,
								 'title',
								 title,
								 'disabled',
								 b2c(nvl(disabled, gv_disabled))));
	end;

	function input_reset(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
											 disabled boolean := null) return varchar2 is
	begin
		return tpl(false,
							 'input',
							 null,
							 ac,
							 st('type',
									'reset',
									'name',
									name,
									'value',
									value,
									'title',
									title,
									'disabled',
									b2c(nvl(disabled, gv_disabled))));
	end;

	procedure input_reset(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
												disabled boolean := null) is
	begin
		gv := tpl(true,
							'input',
							null,
							ac,
							st('type',
								 'reset',
								 'name',
								 name,
								 'value',
								 value,
								 'title',
								 title,
								 'disabled',
								 b2c(nvl(disabled, gv_disabled))));
	end;

	procedure select_open(name varchar2 := null, value_ex varchar2 := null, label_ex varchar2 := null, ac st := null,
												title varchar2 := null, sizep pls_integer := null, multiple boolean := false,
												disabled boolean := null) is
	begin
		form_item_open(label_ex, null);
		gv_sv := value_ex;
		gv    := tpl(true,
								 'select',
								 el_open,
								 ac,
								 st('name',
										name,
										'title',
										title,
										'size',
										sizep,
										'multiple',
										b2c(multiple),
										'disabled',
										b2c(nvl(disabled, gv_disabled))));
	end;

	procedure select_close is
	begin
		gv_sv := null;
		tag_close('select');
		form_item_close;
	end;

	procedure select_option(text varchar2, value varchar2 := null, selected boolean := null, ac st := null,
													disabled boolean := null, label varchar2 := null) is
	begin
		gv := tpl(true,
							'option',
							text,
							ac,
							st('value',
								 value,
								 'selected',
								 b2c(nvl(selected, gv_sv = value)),
								 'disabled',
								 b2c(disabled),
								 'label',
								 label));
	end;

	procedure optgroup(label varchar2 := null, ac st := null, disabled boolean := null) is
	begin
		gv := tpl(true, 'optgroup', null, ac, st('label', label, 'disabled', b2c(disabled)));
	end;

	--------------------------------------------------------

	procedure input_radios(name varchar2, sv varchar2 := null, label_ex varchar2 := null, ac st := null,
												 null_ex varchar2 := null, disabled boolean := null) is
		v_checked boolean;
	begin
		form_item_open(label_ex);
		if null_ex is not null then
			label(text => input_radio(name, 'PW_NULL', false, ac, null, disabled) || null_ex);
		end if;
		for i in 1 .. gv_texts.count loop
			v_checked := gv_values(i) = sv or gv_texts(i) = sv;
			label(text => input_radio(name, gv_values(i), v_checked, ac, null, disabled) || gv_texts(i));
		end loop;
		form_item_close;
		gv_texts  := null;
		gv_values := null;
	end;

	procedure input_checkboxes(name varchar2, svs in st := st(), label_ex varchar2 := null, ac st := null,
														 disabled boolean := null) is
		v_svs     varchar2(32000) := cs;
		v_checked boolean;
	begin
		form_item_open(label_ex);
		for i in 1 .. svs.count loop
			v_svs := v_svs || svs(i) || cs;
		end loop;
		for i in 1 .. gv_texts.count loop
			v_checked := instr(v_svs, cs || gv_values(i) || cs) > 0 or instr(v_svs, cs || gv_texts(i) || cs) > 0;
			label(input_checkbox(name, gv_values(i), v_checked, ac, null, disabled) || gv_texts(i));
		end loop;
		form_item_close;
		gv_texts  := null;
		gv_values := null;
	end;

	procedure select_single(name varchar2 := null, sv varchar2 := null, label_ex varchar2 := null, ac st := null,
													null_ex varchar2 := null, title varchar2 := null, sizep pls_integer := null,
													disabled boolean := null) is
		v_sts boolean;
	begin
		form_item_open(label_ex, null);
		gv := tpl(true,
							'select',
							el_open,
							ac,
							st('name',
								 name,
								 'title',
								 title,
								 'size',
								 sizep,
								 'multiple',
								 b2c(false),
								 'disabled',
								 b2c(nvl(disabled, gv_disabled))));
		if gv_texts is not null and gv_values is not null then
			if null_ex is not null then
				select_option(null_ex, 'PW_NULL');
			end if;
			for i in 1 .. gv_values.count loop
				v_sts := sv = gv_values(i) or sv = gv_texts(i);
				select_option(text => gv_texts(i), value => gv_values(i), selected => v_sts);
			end loop;
			gv_texts  := null;
			gv_values := null;
		else
			null;
			-- raise_application_error(-20000, 'p.gv_texts,p.gv_values is null, not data for options');
		end if;
		tag_close('select');
		form_item_close;
	end;

	procedure select_multiple(name varchar2 := null, svs st := null, label_ex varchar2 := null, ac st := null,
														title varchar2 := null, sizep pls_integer := null, disabled boolean := null) is
		v_svs varchar2(32000) := cs;
		v_sts boolean;
	begin
		form_item_open(label_ex, null);
		gv := tpl(true,
							'select',
							el_open,
							ac,
							st('name',
								 name,
								 'title',
								 title,
								 'size',
								 sizep,
								 'multiple',
								 b2c(true),
								 'disabled',
								 b2c(nvl(disabled, gv_disabled))));
		if gv_texts is not null and gv_values is not null then
			for i in 1 .. svs.count loop
				v_svs := v_svs || svs(i) || cs;
			end loop;
			for i in 1 .. gv_values.count loop
				v_sts := instr(v_svs, cs || gv_values(i) || cs) > 0 or instr(v_svs, cs || gv_texts(i) || cs) > 0;
				select_option(text => gv_texts(i), value => gv_values(i), selected => v_sts);
			end loop;
			gv_texts  := null;
			gv_values := null;
		else
			null;
			-- raise_application_error(-2000, 'p.gv_texts,p.gv_values is null, not data for options');
		end if;
		tag_close('select');
		form_item_close;
	end;

	procedure input_list(tag varchar2, name varchar2 := null, svs st := null, label_ex varchar2 := null, ac st := null,
											 disabled boolean := null) is
		sv varchar2(1000) := case
													 when svs is not null then
														svs(1)
												 end;
	begin
		case tag
			when 'checkboxes' then
				input_checkboxes(name, svs, label_ex, ac, disabled => disabled);
			when 'radios' then
				input_radios(name, sv, label_ex, ac, disabled => disabled);
			when 'select_single' then
				select_single(name, sv, label_ex, ac, disabled => disabled);
			when 'select_multiple' then
				select_multiple(name, svs, label_ex, ac, disabled => disabled);
			else
				raise_application_error(-2000, 'input list must be in checkboxes,radios,select_single,select_multiple');
		end case;
	end;

	function is_null(value varchar2) return boolean is
	begin
		return value = 'PW_NULL';
	end;

	----------------- ul/ol/li/dd/dl 等等 ---------------------------

	procedure x7___________ is
	begin
		null;
	end;

	procedure ul_open(ac st := null, id varchar2 := null) is
	begin
		gv := tpl(true, 'ul', el_open, ac, st('id', id));
	end;

	procedure ul_close is
	begin
		tag_close('ul');
	end;

	procedure ol_open(ac st := null, id varchar2 := null) is
	begin
		gv := tpl(true, 'ol', el_open, ac, st('id', id));
	end;

	procedure ol_close is
	begin
		tag_close('ol');
	end;

	procedure li(text varchar2, ac st := null, value pls_integer := null, class varchar2 := null) is
	begin
		gv := tpl(true, 'li', text, ac, st('value', value, 'class', class));
	end;

	procedure li_open(ac st := null, value pls_integer := null, class varchar2 := null) is
	begin
		gv := tpl(true, 'li', el_open, ac, st('value', value, 'class', class));
	end;

	procedure li_close is
	begin
		tag_close('li');
	end;

	procedure dl_open(ac st := null, id varchar2 := null) is
	begin
		gv := tpl(true, 'dl', el_open, ac, st('id', id));
	end;

	procedure dl_close is
	begin
		tag_close('dl');
	end;

	procedure dt(text varchar2, ac st := null) is
	begin
		gv := tpl(true, 'dt', text, ac, null);
	end;

	procedure dt_open(ac st := null) is
	begin
		gv := tpl(true, 'dt', el_open, ac, null);
	end;

	procedure dt_close is
	begin
		tag_close('dt');
	end;

	procedure dd(text varchar2, ac st := null) is
	begin
		gv := tpl(true, 'dd', text, ac, null);
	end;

	procedure dd_open(ac st := null) is
	begin
		gv := tpl(true, 'dd', el_open, ac, null);
	end;

	procedure dd_close is
	begin
		tag_close('dd');
	end;

	procedure tree(cur sys_refcursor) is
		v_level    pls_integer := 0;
		v_pw_level pls_integer;
		v_text     varchar2(1000);
		v_href     varchar2(100);
		v_class    varchar2(100);
		v_cols     pls_integer;
	begin
		-- columns must be pw_level, text, href
		loop
			if v_cols is null then
				begin
					fetch cur
						into v_pw_level, v_text, v_href, v_class;
					v_cols := 4;
				exception
					when others then
						fetch cur
							into v_pw_level, v_text, v_href;
						v_cols := 3;
				end;
			else
				if v_cols = 4 then
					fetch cur
						into v_pw_level, v_text, v_href, v_class;
				elsif v_cols = 3 then
					fetch cur
						into v_pw_level, v_text, v_href;
				end if;
			end if;
		
			exit when cur%notfound;
			if v_pw_level = v_level + 1 then
				-- 深一层
				ul_open;
			else
				li_close;
				for j in 1 .. v_level - v_pw_level loop
					-- 回层
					ul_close;
					li_close;
				end loop;
			end if;
			li_open(class => v_class);
			if v_href is null then
				span(b(v_text));
			else
				span(a(v_text, v_href));
			end if;
			v_level := v_pw_level;
		end loop;
		for j in 1 .. v_level loop
			li_close;
			ul_close;
		end loop;
		close cur;
	end;

	procedure tree(cur sys_refcursor, text varchar2, href varchar2 := null, class varchar2 := null) is
	begin
		li_open(class => class);
		span(a(text, href));
		tree(cur);
		li_close;
	end;

	procedure open_nodes(p_type varchar2) is
	begin
		gv_level := 0;
		gv_type  := p_type;
	end;

	procedure close_nodes is
	begin
		for j in 1 .. gv_level - 1 loop
			li_close;
			ul_close;
		end loop;
		li_close;
		if gv_type = 'tree' then
			ul_close;
		else
			ol_close;
		end if;
	end;

	procedure add_node(p_level pls_integer, p_text varchar2, p_href varchar2 := null) is
	begin
		if p_level = gv_level + 1 then
			-- 深一层
			if gv_type = 'menu' and p_level = 1 then
				ol_open;
			else
				ul_open;
			end if;
		else
			li_close;
			for j in 1 .. gv_level - p_level loop
				-- 回层
				ul_close;
				li_close;
			end loop;
		end if;
		li_open;
		if p_href like 'javascript:%' then
			if gv_type = 'menu' then
				a(p_text, p_href, '_self');
			else
				span(a(p_text, p_href, '_self'));
			end if;
		else
			if gv_type = 'menu' then
				a(p_text, p_href);
			else
				span(a(p_text, p_href));
			end if;
		end if;
		gv_level := p_level;
	end;

	--------------------------------------------------------------------------------

	procedure x8___________ is
	begin
		null;
	end;

	procedure br(count_ex pls_integer := 1) is
	begin
		for i in 1 .. count_ex loop
			tag_indent;
			line('<br/>');
		end loop;
	end;

	procedure hr(sizep pls_integer := null, noshade boolean := null, ac st := null) is
	begin
		gv := tpl(true, 'hr', null, ac, st('size', sizep, 'noshade', b2c(noshade)));
	end;

	function img(src varchar2 := null, alt varchar2 := null, title varchar2 := null, lowsrc varchar2 := null,
							 ac st := null) return varchar2 is
	begin
		return tpl(false, 'img', null, ac, st('src', l(src), 'alt', alt, 'title', title, 'lowsrc', l(lowsrc)));
	end;

	procedure img(src varchar2 := null, alt varchar2 := null, title varchar2 := null, lowsrc varchar2 := null,
								ac st := null) is
	begin
		gv := tpl(true, 'img', null, ac, st('src', l(src), 'alt', alt, 'title', title, 'lowsrc', l(lowsrc)));
	end;

	procedure embed(src varchar2 := null, ac st := null, title varchar2 := null, pluginspage varchar2 := null) is
	begin
		gv := tpl(true, 'embed', null, ac, st('title', title, 'src', l(src), 'pluginspace', pluginspage));
	end;

	procedure object(text varchar2 := null, name varchar2 := null, ac st := null, title varchar2 := null,
									 classid varchar2 := null, codebase varchar2 := null, data varchar2 := null, typep varchar2 := null,
									 alt varchar2 := null) is
	begin
		gv := tpl(true,
							'object',
							text,
							ac,
							st('name',
								 name,
								 'title',
								 title,
								 'classid',
								 classid,
								 'codebase',
								 l(codebase),
								 'data',
								 l(data),
								 'type',
								 typep,
								 'alt',
								 alt));
	end;

	procedure object_open(name varchar2 := null, ac st := null, title varchar2 := null, classid varchar2 := null,
												codebase varchar2 := null, data varchar2 := null, typep varchar2 := null, alt varchar2 := null) is
	begin
		gv := tpl(true,
							'object',
							el_open,
							ac,
							st('name',
								 name,
								 'title',
								 title,
								 'classid',
								 classid,
								 'codebase',
								 l(codebase),
								 'data',
								 l(data),
								 'type',
								 typep,
								 'alt',
								 alt));
	end;

	procedure object_close is
	begin
		tag_close('object');
	end;

	procedure param(name varchar2, value varchar2, ac st := null, valuetype varchar2 := null, typep varchar2 := null) is
	begin
		gv := tpl(true, 'param', null, ac, st('name', name, 'value', value, 'valuetype', valuetype, 'type', typep));
	end;

	procedure xml(id varchar2, src varchar2) is
	begin
		gv := tpl(true, 'xml', ' ', null, st('src', l(src), 'id', id));
	end;

	procedure xml_open(id varchar2, ac st := null) is
	begin
		gv := tpl(true, 'xml', el_open, ac, st('id', id));
	end;

	procedure xml_close is
	begin
		tag_close('xml');
	end;

	-------------------------------------------------------------------------

	-- 纯文本(换行)
	procedure print(text varchar2) is
	begin
		tag_indent;
		line(text);
	end;

	-- public
	procedure comment(text varchar2) is
		v varchar2(2000);
	begin
		if nvl(text, el_open) != el_close then
			v := '<!-- ';
		end if;
		if text not in (el_open, el_close) then
			v := v || text;
		end if;
		if nvl(text, el_close) != el_open then
			v := v || ' -->';
		end if;
		tag_indent;
		line(v);
	end;

	-- public
	procedure blank_line(amount pls_integer := null) is
	begin
		if amount is null then
			line;
		else
			for i in 1 .. amount loop
				line;
			end loop;
		end if;
	end;

	function a(text varchar2, href varchar2 := null, target varchar2 := null, ac st := null, method varchar2 := null)
		return varchar2 is
	begin
		return tpl(false, 'a', text, ac, st('href', l(href, true), 'target', target, 'methods', method));
	end;

	procedure a(text varchar2, href varchar2 := null, target varchar2 := null, ac st := null, method varchar2 := null) is
	begin
		gv := tpl(true, 'a', text, ac, st('href', l(href, true), 'target', target, 'methods', method));
	end;

	----------------

	procedure x9___________ is
	begin
		null;
	end;

	procedure frameset_open(name varchar2 := null, rows varchar2 := null, cols varchar2 := null, ac st := null,
													frameborder varchar2 := null, framespacing varchar2 := null, bordercolor varchar2 := null) is
	begin
		gv := tpl(true,
							'frameset',
							el_open,
							ac,
							st('name',
								 name,
								 'rows',
								 rows,
								 'cols',
								 cols,
								 'frameborder',
								 frameborder,
								 'framespacing',
								 framespacing,
								 'bordercolor',
								 bordercolor));
	end;

	procedure frameset_close is
	begin
		tag_close('frameset');
	end;

	procedure frame(name varchar2 := null, src varchar2 := null, ac st := null, frameborder varchar2 := null,
									scrolling varchar2 := null, noresize boolean := null) is
	begin
		assert(gv_tag_len > 0 and gv_tags(gv_tag_len) = 'frameset', 'frame 必须在 frameset 中使用');
		gv := tpl(true,
							'frame',
							null,
							ac,
							st('name',
								 name,
								 'src',
								 l(src),
								 'frameborder',
								 frameborder,
								 'scrolling',
								 scrolling,
								 'noresize',
								 b2c(noresize)));
	end;

	procedure iframe(name varchar2 := null, src varchar2 := null, ac st := null, frameborder varchar2 := null,
									 scrolling varchar2 := null) is
	begin
		gv := tpl(true,
							'iframe',
							null,
							ac,
							st('name', name, 'src', l(src), 'frameborder', frameborder, 'scrolling', scrolling));
	end;

	------------------------------

	procedure cfg_init is
	begin
		gv_class      := st();
		gv_label      := st();
		gv_align      := st();
		gv_width      := st();
		gv_style      := st();
		gv_format     := st();
		gv_item_count := 0;
	end;

	procedure cfg_add(class varchar2, label varchar2, align varchar2 := 'center', width varchar2 := null,
										style varchar2 := null, format varchar2 := null) is
		i integer;
	begin
		gv_item_count := gv_item_count + 1;
		i             := gv_item_count;
		gv_class.extend;
		gv_label.extend;
		gv_align.extend;
		gv_width.extend;
		gv_style.extend;
		gv_format.extend;
		gv_class(i) := class;
		gv_label(i) := label;
		gv_align(i) := align;
		gv_width(i) := width;
		gv_style(i) := style;
		gv_format(i) := format;
	end;

	procedure cfg_cols_bak is
	begin
		for i in 1 .. gv_item_count loop
			if gv_width(i) is not null then
				col(class => gv_class(i), align => gv_align(i), ac => st('#width:?1;' || gv_style(i), gv_width(i)));
			else
				col(class => gv_class(i), align => gv_align(i), ac => st(gv_style(i)));
			end if;
		end loop;
	end;

	procedure cfg_cols is
	begin
		for i in 1 .. gv_item_count loop
			if gv_width(i) is not null then
				col(class => gv_class(i), ac => st('#width:?1;', gv_width(i)));
			else
				col(class => gv_class(i));
			end if;
		end loop;
	end;

	-- private
	procedure nnappend(p_tar in out nocopy varchar2, p_str varchar2, p_prefix varchar2, p_suffix varchar2 := null) is
	begin
		if p_str is null then
			return;
		end if;
		p_tar := p_tar || p_prefix || p_str || p_suffix;
	end;

	procedure cfg_css_old is
		v_sel varchar2(1000) := ' table';
		v_css varchar2(1000);
	begin
		nnappend(v_sel, gv_table_id, '#');
		v_sel := v_sel || ' > tbody > tr > *:first-child';
		--print('<style>');
		for i in 1 .. gv_item_count loop
			v_css := gv_style(i);
			nnappend(v_css, gv_align(i), 'text-align:', ';');
			-- nnappend(v_css, gv_width(i), 'width:', ';');
			css(v_sel || ' { ' || v_css || ' }');
			v_sel := v_sel || ' + *';
		end loop;
		--print('</style>');
	end;

	procedure cfg_css is
		v_sel varchar2(1000) := ' table';
		v_css varchar2(1000);
	begin
		nnappend(v_sel, gv_table_id, '#');
		v_sel := v_sel || ' > tbody > tr > *:nth-child(';
		-- v_sel := v_sel || ' > col:nth-child(';
		for i in 1 .. gv_item_count loop
			v_css := gv_style(i);
			nnappend(v_css, gv_align(i), 'text-align:', ';');
			-- nnappend(v_css, gv_width(i), 'width:', ';');
			css(v_sel || i || ') { ' || v_css || ' }');
		end loop;
	end;

	procedure cfg_ths is
	begin
		for i in 1 .. gv_item_count loop
			th(text => gv_label(i));
		end loop;
	end;

	procedure cfg_cols_thead is
	begin
		--cfg_css;
		cfg_css;
		cfg_cols;
		thead_open;
		tr_open;
		cfg_ths;
		tr_close;
		thead_close;
	end;

	procedure cfg_content(cur in out nocopy sys_refcursor, fmt_date varchar2 := null, group_size pls_integer := null) is
		type curtype is ref cursor;
		curid      number;
		desctab    dbms_sql.desc_tab;
		colcnt     number;
		v_varchar2 varchar2(2000);
		v_number   number;
		v_date     date;
		v_other    varchar2(2000);
		v_col_name varchar2(1000);
		v_collen   binary_integer;
		v_grp_cnt  pls_integer := 0;
		procedure set_align(p_align varchar2, i pls_integer) is
		begin
			if gv_align(i) = 'auto' then
				gv_align(i) := p_align;
			end if;
		end;
	begin
		curid := dbms_sql.to_cursor_number(cur);
		dbms_sql.describe_columns(curid, colcnt, desctab);
	
		for i in 1 .. colcnt loop
			case desctab(i).col_type
				when 1 then
					dbms_sql.define_column(curid, i, v_varchar2, 2000);
					set_align('left', i);
				when 2 then
					dbms_sql.define_column(curid, i, v_number);
					set_align('right', i);
				when 12 then
					dbms_sql.define_column(curid, i, v_date);
					set_align('center', i);
				else
					dbms_sql.define_column(curid, i, v_other, 2000);
					set_align('center', i);
			end case;
		end loop;
	
		-- set tbody cols css
		cfg_css;
	
		-- for col and width
		for i in 1 .. colcnt loop
			v_col_name := lower(desctab(i).col_name);
			v_collen   := desctab(i).col_max_len;
			print('<col class="pwc_' || v_col_name || '"' || case when gv_width(i) is not null then
						' style="width:' || replace(gv_width(i), 'pw', v_collen || 'ex') || ';"/>' end);
		end loop;
	
		-- thead label use cfg or alias
		thead_open;
		tr_open;
		for i in 1 .. gv_item_count loop
			th(text => nvl(gv_label(i), desctab(i).col_name));
		end loop;
		tr_close;
		thead_close;
	
		-- Fetch Rows
		tbody_open;
		gv_count := 0;
		while dbms_sql.fetch_rows(curid) > 0 loop
			gv_count := gv_count + 1;
			tr_open;
			for i in 1 .. colcnt loop
				case desctab(i).col_type
					when 1 then
						dbms_sql.column_value(curid, i, v_varchar2);
						td(v_varchar2);
					when 2 then
						dbms_sql.column_value(curid, i, v_number);
						if gv_format(i) is not null then
							td(to_char(v_number, gv_format(i)));
						else
							td(to_char(v_number));
						end if;
					when 12 then
						dbms_sql.column_value(curid, i, v_date);
						td(to_char(v_date, coalesce(gv_format(i), fmt_date, 'yyyy-mm-dd')));
					else
						dbms_sql.column_value(curid, i, v_other);
						td(v_other);
				end case;
			end loop;
			tr_close;
			if group_size is not null then
				v_grp_cnt := v_grp_cnt + 1;
				if v_grp_cnt = group_size then
					v_grp_cnt := 0;
					tbody_close;
					tbody_open;
				end if;
			end if;
		end loop;
		tbody_close;
	
		dbms_sql.close_cursor(curid);
	exception
		when no_data_found then
			tbody_close;
			dbms_sql.close_cursor(curid);
	end;

	procedure plsql_marker(unit varchar2, lineno pls_integer, text varchar2 := null) is
	begin
		comment(text || ' @ ' || unit || '.' || lineno);
	end;

	-- sub component start marker
	procedure plsql_begin(unit varchar2, lineno pls_integer) is
	begin
		line;
		plsql_marker(unit, lineno, 'BEGIN');
	end;

	-- sub conponent end marker
	procedure plsql_end(unit varchar2, lineno pls_integer) is
	begin
		plsql_marker(unit, lineno, '.END.');
		line;
	end;

end k_xhtp;
/

