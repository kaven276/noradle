create or replace package body k_xhtp is

	pragma serially_reusable;

	cs constant char(1) := '~';
	gv_tag_indent pls_integer;
	gv_tagnl      varchar(2);
	gv_1st_lcss   boolean;

	gv_wap          boolean := false;
	gv_html_type    varchar2(100);
	gv_doc_type_str varchar2(200);
	gv_compatible   varchar2(100);
	gv_vml          boolean := false;

	gv_sv             varchar2(32000);
	gv_form_item_open boolean;
	gv_readonly       boolean; -- form's readonly default for text/password/textarea
	gv_disabled       boolean; -- form's disable default for select/checkbox/radio

	-- API output adjustment related
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

	-- tag stack
	type t_tags is table of varchar2(30) index by pls_integer;
	gv_tag_len pls_integer; -- first tag is body, depth is 1
	gv_tags    t_tags;
	gv_check   boolean;

	gv_head_over boolean; -- control where to output

	-- for auto close body/html tags
	gv_need_html_close boolean := false;
	gv_need_body_close boolean := false;

	-- convert tags for head to in body
	gv_in_body boolean := false;

	-- record if there has errors in output
	gv_has_error boolean := false;

	gv_cur_seq pls_integer := 0;

	gv_force_css_cv boolean := false;
	gv_css_prefix   varchar2(10);

	gv_nc boolean;

	function next_seq return varchar2 is
	begin
		gv_cur_seq := gv_cur_seq + 1;
		return 'pw_' || gv_cur_seq;
	end;

	---------

	procedure format_src(line_break varchar2 := nl) is
	begin
		gv_tagnl := line_break;
		if line_break is null then
			gv_tag_indent := 0;
		else
			gv_tag_indent := 2;
		end if;
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

	function tf(cond boolean, true_str varchar2 character set any_cs, false_str varchar2 character set any_cs)
		return varchar2 character set true_str%charset is
	begin
		-- return case when cond then true_str else false_str end;
		if cond then
			return true_str;
		else
			return false_str;
		end if;
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
		r varchar2(32000) := p; -- utl_url.escape(p, false, pv.charset_ora);
	begin
		if r like 'u:%' then
			return u(trim(substr(r, 3)), to_proc);
		elsif r is not null then
			return u(r, to_proc);
		else
			return '';
		end if;
	end;

	----------------------

	procedure prn(text varchar2 character set any_cs) is
	begin
		output.line(text, '');
	end;

	procedure prn(text in out nocopy clob character set any_cs) is
	begin
		output.line(text, '');
	end;

	procedure d(text varchar2 character set any_cs) is
	begin
		output.line(text, '', (gv_tag_len - 2) * gv_tag_indent);
	end;

	-- private: nocopy version for line, ref only by tpl
	procedure line2(text in out nocopy varchar2 character set any_cs) is
	begin
		output.line(text, gv_tagnl, (gv_tag_len - 2) * gv_tag_indent);
	end;

	procedure line(text varchar2 character set any_cs := '') is
	begin
		output.line(text, gv_tagnl, (gv_tag_len - 2) * gv_tag_indent);
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
		if cv or gv_force_css_cv then
			v_text := replace(v_text, '^', gv_css_prefix);
		end if;
		if gv_scale then
			px(v_text);
		end if;
		output.css(v_text || gv_tagnl);
	end;

	procedure css(text varchar2, vals st, cv boolean) is
	begin
		css(ps(text, vals, ch => '$'), cv);
	end;

	procedure comp_css_link(setting boolean) is
	begin
		if setting is null then
			pv.csslink := null;
		elsif output.prevent_flush('p.comp_css_link') then
			pv.csslink := setting;
		end if;
	end;

	procedure print_cgi_env is
		n varchar2(99);
		v varchar2(999);
	begin
		n := ra.headers.first;
		loop
			exit when n is null;
			v := ra.headers(n);
			line(n || ' = ' || v);
			n := ra.headers.next(n);
		end loop;
	end;

	procedure go(url varchar2, vals st := null, info varchar2 := null) is
		v_url varchar2(1000);
	begin
		v_url := l(url, true);
		-- prefix ./ , so some buggy browsers do not treat as /xxx instead of relative path
		v_url := t.tf(not regexp_like(v_url, '(http://|/|./|../).*'), './') || v_url;
		if vals is not null then
			v_url := ps(v_url, vals);
		end if;
	
		if info is null then
			k_http.go('=' || v_url);
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
		g.finish;
	end;

	-- public
	function is_dhc return boolean is
	begin
		return not gv_in_body;
	end;

	procedure assert(cond boolean, info varchar2) is
	begin
		if not cond then
			raise_application_error(-20996, info);
			gv_has_error := true;
			line('<noscript>');
			line(info || gv_tagnl);
			line(dbms_utility.format_call_stack);
			line('</noscript>');
		end if;
	end;

	-- public
	procedure ensure_close is
		v_err_msg varchar2(200);
	begin
		if true then
			case nvl(gv_tag_len, 0)
				when 0 then
					null; -- ok;
				when 1 then
					assert(gv_tags(1) = 'html', 'There are unclosed tag is before </html>.');
				when 2 then
					assert(gv_tags(2) = 'body', 'There are unclosed tag is before </body>.');
				else
					for i in 3 .. gv_tag_len loop
						v_err_msg := v_err_msg || nl || gv_tags(i);
					end loop;
					assert(false, 'There are tags not closed ' || v_err_msg);
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
	
	end;

	---------------------------------------------------------------------------

	procedure x0___________ is
	begin
		null;
	end;

	---------------------------------------------------------------------------

	function w(text varchar2 character set any_cs) return varchar2 character set text%charset is
	begin
		return regexp_replace(text, '(.)', '<b>\1</b>');
	end;

	function ps(pat varchar2 character set any_cs, vals st, url boolean := null, ch char := ':') return varchar2 character set pat%charset is
		v_str varchar2(32000) := pat;
		v_chr char(1) := chr(0);
	begin
		for i in 1 .. vals.count loop
			v_str := replace(v_str, ch || i, v_chr || vals(i));
		end loop;
		return replace(v_str, v_chr, '');
	end;

	procedure ps(pat varchar2 character set any_cs, vals st, url boolean := null, ch char := ':') is
	begin
		line(ps(pat, vals, url, ch));
	end;

	-- private : to avoid string concat
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

	function get_tag(full_tag varchar2 character set any_cs) return varchar2 character set full_tag%charset is
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

	-- private
	function prop(name varchar2, value varchar2 character set any_cs) return varchar2 character set value%charset is
	begin
		if value is null then
			return '';
		end if;
		return ' ' || name || '="' || value || '"';
	end;

	procedure tag_push(tag varchar2) is
	begin
		gv_tag_len := gv_tag_len + 1;
		gv_tags(gv_tag_len) := tag;
	end;

	procedure tag_pop(tag varchar2) is
	begin
		if gv_check then
			assert(gv_tags(gv_tag_len) = tag, 'tag nesting error, no matching open tag for this close tag.' || gv_tag_len);
		end if;
		gv_tag_len := gv_tag_len - 1;
	end;

	-- private, common tag output API
	function tpl(output boolean, name varchar2, text varchar2 character set any_cs, ac in st, da st,
							 prop varchar2 character set text%charset := null) return varchar2 character set text%charset is
		v_ac  varchar2(4000) character set text%charset;
		v_a1  varchar2(4000) character set text%charset;
		v_a2  varchar2(4000) character set text%charset;
		v_s   varchar2(4000) character set text%charset;
		v_pos pls_integer;
		m     varchar2(32000) character set text%charset;
		v_tag varchar2(30) := name;
	begin
		-- head part tag api will not use me, body,frameset(include itself) will call me
		if gv_check and pv.mime_type != 'text/plain' then
			assert(instrb(',html,head,body,frameset,frame,hta:application,title,base,meta,link,script,style,',
										',' || v_tag || ',') > 0 or gv_tags(2) = 'body',
						 ' this tag ' || v_tag || 'must used in body tag');
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
				if gv_check and substr(v_ac, -1) != ';' then
					raise_application_error(-20000, 'maybe lose ;');
				end if;
				-- name=#sddsf;name2=#dfsdf#css1:dsfds;css2:xcxcv;
				v_a1 := replace(replace(' ' || v_ac, '=', '="'), ';', '" '); -- todo: one more space problem
				v_s  := null;
			end if;
		end if;
		if gv_check and instrb(v_a1, ':') > 0 then
			raise_application_error(-20000, 'attributes must use =, and not :, for [' || v_ac || ']');
		end if;
	
		-- free attributes part
		if da is not null then
			for i in 1 .. floor(da.count / 2) loop
				if gv_check then
					assert(da(i * 2 - 1) = lower(da(i * 2 - 1)), 'xhtml attribute name must be in lower case:' || da(i * 2 - 1));
				end if;
				if da(i * 2) is not null then
					v_a2 := v_a2 || (' ' || da(i * 2 - 1) || '="' || da(i * 2) || '"');
				end if;
			end loop;
			if gv_auto_input_class and name = 'input' then
				v_a1 := v_a1 || ' class="' || substr(da(2), 1, 1) || '"';
			end if;
		end if;
	
		case text
			when el_open then
				m := '<' || name || prop || v_a2 || v_a1 || v_s || '>';
			when el_close then
				m := '</' || v_tag || '>';
			else
				if text is null then
					if regexp_like(name, '^(base|meta|br|hr|col|input|img|link|area|param)$') then
						-- |embed|object|frame
						m := '<' || name || prop || v_a2 || v_a1 || v_s || '/>';
					else
						m := '<' || name || prop || v_a2 || v_a1 || v_s || '></' || v_tag || '>';
					end if;
				else
					m := '<' || name || prop || v_a2 || v_a1 || v_s || '>' || text || '</' || v_tag || '>';
				end if;
		end case;
	
		if output then
			case text
				when el_open then
					line2(m);
					tag_push(v_tag);
				when el_close then
					tag_pop(v_tag);
					line2(m);
				else
					line2(m);
			end case;
			return null;
		else
			return m;
		end if;
	
	end;

	function tag(name varchar2, text varchar2 character set any_cs, ac st, da st) return varchar2 character set text%charset is
	begin
		return tpl(false, name, text, ac, da);
	end;

	procedure tag(name varchar2, text varchar2 character set any_cs, ac st, da st) is
	begin
		gv := tpl(true, name, text, ac, da);
	end;

	procedure tag_open(name varchar2, ac st := null, da st := null) is
	begin
		gv := tpl(true, name, el_open, ac, da);
	end;

	procedure tag_close(name varchar2) is
	begin
		tag_pop(name);
		d('</' || name || '>' || gv_tagnl);
	end;

	---------------------------------------------------------------------------

	procedure x1___________ is
	begin
		null;
	end;

	procedure init is
	begin
		--scn         := null;
		gv_xhtp    := false; -- after p.doc_type, become true
		gv_in_body := false; -- reset is_dhc to true for not using k_gw
		meta_init;
		if pv.firstpg then
			gv_check            := not pv.production;
			pv.csslink          := null;
			gv_auto_input_class := false;
			gv_force_css_cv     := false;
			gv_css_prefix       := '';
			gv_html_type        := 'transitional';
			format_src(null);
		elsif pv.flushed then
			raise_application_error(-20991, 'flushed page can not be regenerated!');
		end if;
		output."_init"(80526);
	end;

	procedure http_header_close is
	begin
		-- clear http headers
		gv_xhtp := false;
		gv_head_over := true;
		gv_tag_len := 0;
		gv_tags(1) := null;
		gv_tags(2) := null;
		gv_has_error := false;
	end;

	procedure doc_type(name varchar2) is
	begin
		http_header_close;
		gv_xhtp := true;
	
		case lower(nvl(name, gv_html_type))
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
			else
				gv_doc_type_str := name;
		end case;
	
		gv_head_over := false;
		-- '<?xml version="1.0"?>' || nl;
		output.line(gv_doc_type_str, nl);
	
		if pv.cs_char = pv.charset_ora then
			gv_nc := false;
		else
			gv_nc := null;
		end if;
	end;

	procedure use_vml is
	begin
		gv_vml := true;
	end;

	procedure set_compatible(value varchar2) is
	begin
		gv_compatible := value;
	end;

	procedure set_check(value boolean) is
	begin
		gv_check := value;
	end;
	
	procedure set_html_type(value varchar2) is
	begin
		gv_html_type := value;
	end;

	procedure html_open(manifest varchar2 := null) is
	begin
		assert(gv_tag_len is not null,
					 'System exception, xhtml page has not output doc_type declaration in the first line.');
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
		assert(gv_tag_len = 1 and gv_tags(1) = 'html', 'head tag must be positioned directly under html tag.');
		line('<head>');
		tag_push('head');
		line('<meta name="generator" content="PSP.WEB"/>');
		meta_http_equiv('Content-Type', 'text/html;charset=' || pv.charset);
	end;

	procedure head_close is
	begin
		if gv_compatible is not null then
			meta_http_equiv('X-UA-Compatible', gv_compatible);
		end if;
		if gv_vml then
			line('<?import namespace="v" implementation="#default#VML"?>');
			line('<?import namespace="o" implementation="#default#VML"?>');
			line('<style type="text/css">v\:*, o\:* { behavior:url(#default#VML);display:block; }</style>');
		end if;
		gv_head_over := true;
	
		if pv.csslink is not null then
			output.switch_css;
		end if;
	
		tag_pop('head');
		line('</head>');
	end;

	procedure body_open(ac st := null) is
	begin
		assert(gv_tag_len = 1 and gv_tags(1) = 'html', 'body tag must be positioned directly under html tag.');
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

	----------------- head part -----------------------------------------------

	procedure x3___________ is
	begin
		null;
	end;

	procedure assert_in_head(tag varchar2) is
	begin
		if gv_check then
			assert(gv_tag_len = 2 and gv_tags(2) = 'head', tag || ' must used in head tag range.');
		end if;
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

	procedure title(text varchar2 character set any_cs) is
		v_title varchar2(1000) character set text%charset;
	begin
		assert_in_head('title');
		v_title := '<title>' || text || '</title>';
		line2(v_title);
	end;

	procedure title2(text varchar2 character set any_cs) is
	begin
		title(text);
	end;

	procedure base(href varchar2 := null, target varchar2 := null) is
	begin
		assert_in_head('base');
		gv := tpl(true, 'base', null, null, st('href', l(href), 'target', nvl(target, '_self')));
	end;

	procedure meta_init is
	begin
		assert(not gv_xhtp, 'p.meta_init must be used before page output begin');
		gv_st     := st();
		gv_texts  := st();
		gv_values := st();
	end;

	procedure meta(content varchar2, http_equiv varchar2 default null, name varchar2 default null) is
		v_idx pls_integer := gv_st.count + 1;
	begin
		assert(not (http_equiv is not null and name is not null), 'http_equiv and name can be set ether, but not both.');
		assert(http_equiv is null or name is null, 'both http_equiv and name is null, it must have one set.');
		if not gv_xhtp then
			-- if meta has not output yet, save them to package array
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

	procedure script_text(text varchar2 character set any_cs) is
	begin
		script_open;
		line(text);
		script_close;
	end;

	procedure js(text varchar2 character set any_cs) is
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

	procedure html_head(title varchar2 character set any_cs default 'psp.web', links st := null, scripts st := null,
											body boolean default true) is
	begin
		if not gv_xhtp then
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

	procedure h(files varchar2 := null, title varchar2 character set any_cs default 'psp.web', target varchar2 := null,
							href varchar2 := null, charset varchar2 := null, manifest varchar2 := '') is
		v_file varchar2(32000);
	begin
		if not is_dhc then
			return;
		end if;
		doc_type;
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

	-------------------- body part -------------------------------------------------

	procedure x4___________ is
	
	begin
		null;
	end;

	procedure hn(level pls_integer, text varchar2 character set any_cs := null, ac st := null) is
	begin
		assert(level between 1 and 6, 'hn level must be between 1 and 6.');
		gv := tpl(true, 'h' || level, text, ac, null);
	end;

	procedure p(text varchar2 character set any_cs := null, ac st := null) is
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

	function span(text varchar2 character set any_cs := null, ac st := null, title varchar2 := null) return varchar2 character set text%charset is
	begin
		return tpl(false, 'span', text, ac, st('title', title));
	end;

	procedure span(text varchar2 character set any_cs := null, ac st := null, title varchar2 := null,
								 class varchar2 := null) is
	begin
		gv := tpl(true, 'span', text, ac, st('title', title, 'class', class));
	end;

	function b(text varchar2 character set any_cs := null, ac st := null, title varchar2 := null) return varchar2 character set text%charset is
	begin
		return tpl(false, 'b', text, ac, st('title', title));
	end;

	procedure b(text varchar2 character set any_cs := null, ac st := null, title varchar2 := null, class varchar2 := null) is
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

	procedure legend(text varchar2 character set any_cs, ac st := null, title varchar2 := null) is
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

	procedure caption(text varchar2 character set any_cs, ac st := null, title varchar2 := null) is
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
		for i in 1 .. classes.count loop
			d('<col class="' || classes(i) || '"/>');
		end loop;
		line;
	end;

	procedure cols(classes varchar2, sep varchar2 := ',') is
	begin
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
		line('<table class="pw_shrink"><tr><td>');
		tag_push('table_tr_td');
	end;

	procedure table_tr_td_close is
	begin
		tag_pop('table_tr_td');
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

	procedure tr(text varchar2 character set any_cs, ac st := null, class varchar2 := null) is
	begin
		gv := tpl(true, 'tr', text, ac, st('class', class || ' ' || tr_switch));
	end;

	function tr(text varchar2 character set any_cs, ac st := null) return varchar2 character set text%charset is
	begin
		return tpl(false, 'tr', text, ac, null);
	end;

	procedure td(text varchar2 character set any_cs, ac st := null, title varchar2 := null, colspan pls_integer := null,
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

	function td(text varchar2 character set any_cs, ac st := null, title varchar2 := null, colspan pls_integer := null,
							rowspan pls_integer := null, class varchar2 := null) return varchar2 character set text%charset is
	begin
		return tpl(false, 'td', text, ac, st('title', title, 'colspan', colspan, 'rowspan', rowspan, 'class', class));
	end;

	procedure th(text varchar2 character set any_cs, ac st := null, title varchar2 := null, colspan pls_integer := null,
							 rowspan pls_integer := null, class varchar2 := null) is
	begin
		gv := tpl(true, 'th', text, ac, st('title', title, 'colspan', colspan, 'rowspan', rowspan, 'class', class));
	end;

	function th(text varchar2 character set any_cs, ac st := null, title varchar2 := null, colspan pls_integer := null,
							rowspan pls_integer := null, class varchar2 := null) return varchar2 character set text%charset is
	begin
		return tpl(false, 'th', text, ac, st('title', title, 'colspan', colspan, 'rowspan', rowspan, 'class', class));
	end;

	procedure ths(texts st) is
	begin
		for i in 1 .. texts.count loop
			d('<th>' || texts(i) || '</th>');
		end loop;
		line;
	end;

	procedure tds(texts st) is
	begin
		for i in 1 .. texts.count loop
			d('<td>' || texts(i) || '</td>');
		end loop;
		line;
	end;

	procedure ths(texts varchar2, sep varchar2 := ',') is
	begin
		line('<th>' || replace(texts, sep, '</th><th>') || '</th>');
	end;

	procedure tds(texts varchar2, sep varchar2 := ',') is
	begin
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

	procedure label(text varchar2 character set any_cs, ac st := null, title varchar2 := null, forp varchar2 := null) is
	begin
		gv := tpl(true, 'label', text, ac, st('title', title, 'for', forp));
	end;

	function label(text varchar2 character set any_cs, ac st := null, title varchar2 := null, forp varchar2 := null)
		return varchar2 character set text%charset is
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

	function input_checkbox(name varchar2 := null, value varchar2 character set any_cs := null, checked boolean := false,
													ac st := null, title varchar2 := null, disabled boolean := null) return varchar2 character set value%charset is
		v_text varchar2(1) character set value%charset := '';
	begin
		return tpl(false,
							 'input',
							 v_text,
							 ac,
							 st('type',
									'checkbox',
									'name',
									name,
									'title',
									title,
									'checked',
									b2c(checked),
									'disabled',
									b2c(nvl(disabled, gv_disabled))),
							 prop('value', value));
	end;

	procedure input_checkbox(name varchar2 := null, value varchar2 character set any_cs := null,
													 label_ex varchar2 := null, checked boolean := false, ac st := null, title varchar2 := null,
													 disabled boolean := null) is
		v_text varchar2(1) character set value%charset := '';
	begin
		form_item_open(label_ex, null);
		gv := tpl(true,
							'input',
							v_text,
							ac,
							st('type',
								 'checkbox',
								 'name',
								 name,
								 'title',
								 title,
								 'checked',
								 b2c(checked),
								 'disabled',
								 b2c(nvl(disabled, gv_disabled))),
							prop('value', value));
		form_item_close;
	end;

	function input_radio(name varchar2 := null, value varchar2 character set any_cs := null, checked boolean := false,
											 ac st := null, title varchar2 := null, disabled boolean := null) return varchar2 character set value%charset is
		v_text varchar2(1) character set value%charset := '';
	begin
		return tpl(false,
							 'input',
							 v_text,
							 ac,
							 st('type',
									'radio',
									'name',
									name,
									'title',
									title,
									'checked',
									b2c(checked),
									'disabled',
									b2c(nvl(disabled, gv_disabled))),
							 prop('value', value));
	end;

	procedure input_radio(name varchar2 := null, value varchar2 character set any_cs := null, label_ex varchar2 := null,
												checked boolean := false, ac st := null, title varchar2 := null, disabled boolean := null) is
		v_text varchar2(1) character set value%charset := '';
	begin
		form_item_open(label_ex);
		gv := tpl(true,
							'input',
							v_text,
							ac,
							st('type',
								 'radio',
								 'name',
								 name,
								 'title',
								 title,
								 'checked',
								 b2c(checked),
								 'disabled',
								 b2c(nvl(disabled, gv_disabled))),
							prop('value', value));
		form_item_close;
	end;

	procedure input_hidden(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null) is
		v_text varchar2(1) character set value%charset := '';
	begin
		gv := tpl(true, 'input', v_text, ac, st('type', 'hidden', 'name', name), prop('value', value));
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

	function input_password(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
													title varchar2 := null, sizep pls_integer := null, maxlength pls_integer := null,
													readonly boolean := null, disabled boolean := null) return varchar2 character set value%charset is
		v_text varchar2(1) character set value%charset := '';
	begin
		return tpl(false,
							 'input',
							 v_text,
							 ac,
							 st('type',
									'password',
									'name',
									name,
									'title',
									title,
									'size',
									sizep,
									'maxlength',
									maxlength,
									'readonly',
									b2c(nvl(readonly, gv_readonly)),
									'disabled',
									b2c(disabled)),
							 prop('value', value));
	end;

	procedure input_password(name varchar2 := null, value varchar2 character set any_cs := null,
													 label_ex varchar2 := null, ac st := null, title varchar2 := null, sizep pls_integer := null,
													 maxlength pls_integer := null, readonly boolean := null, disabled boolean := null) is
		v_text varchar2(1) character set value%charset := '';
	begin
		form_item_open(label_ex, null);
		gv := tpl(true,
							'input',
							v_text,
							ac,
							st('type',
								 'password',
								 'name',
								 name,
								 'title',
								 title,
								 'size',
								 sizep,
								 'maxlength',
								 maxlength,
								 'readonly',
								 b2c(nvl(readonly, gv_readonly)),
								 'disabled',
								 b2c(disabled)),
							prop('value', value));
		form_item_close;
	end;

	function input_text(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
											title varchar2 := null, sizep pls_integer := null, maxlength pls_integer := null,
											readonly boolean := null, disabled boolean := null) return varchar2 character set value%charset is
		v_text varchar2(1) character set value%charset := '';
	begin
		return tpl(false,
							 'input',
							 v_text,
							 ac,
							 st('type',
									'text',
									'name',
									name,
									'title',
									title,
									'size',
									sizep,
									'maxlength',
									maxlength,
									'readonly',
									b2c(nvl(readonly, gv_readonly)),
									'disabled',
									b2c(disabled)),
							 prop('value', value));
	end;

	procedure input_text(name varchar2 := null, value varchar2 character set any_cs := null, label_ex varchar2 := null,
											 ac st := null, title varchar2 := null, sizep pls_integer := null, maxlength pls_integer := null,
											 readonly boolean := null, disabled boolean := null) is
		v_text varchar2(1) character set value%charset := '';
	begin
		form_item_open(label_ex, null);
		gv := tpl(true,
							'input',
							v_text,
							ac,
							st('type',
								 'text',
								 'name',
								 name,
								 'title',
								 title,
								 'size',
								 sizep,
								 'maxlength',
								 maxlength,
								 'readonly',
								 b2c(nvl(readonly, gv_readonly)),
								 'disabled',
								 b2c(disabled)),
							prop('value', value));
		form_item_close;
	end;

	function textarea(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
										title varchar2 := null, rows pls_integer := null, cols pls_integer := null, readonly boolean := null,
										disabled boolean := null) return varchar2 character set value%charset is
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

	procedure textarea(name varchar2 := null, value varchar2 character set any_cs := null, label_ex varchar2 := null,
										 ac st := null, title varchar2 := null, rows pls_integer := null, cols pls_integer := null,
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

	procedure button(name varchar2, value varchar2, text varchar2 character set any_cs, ac st := null,
									 title varchar2 := null, disabled boolean := null) is
	begin
		gv := tpl(true,
							'button',
							text,
							ac,
							st('name', name, 'title', title, 'disabled', b2c(disabled)),
							prop('value', value));
	end;

	function input_button(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
												title varchar2 := null, disabled boolean := null) return varchar2 character set value%charset is
		v_text varchar2(1) character set value%charset := '';
	begin
		return tpl(false,
							 'input',
							 v_text,
							 ac,
							 st('type', 'button', 'name', name, 'title', title, 'disabled', b2c(nvl(disabled, gv_disabled))),
							 prop('value', value));
	end;

	procedure input_button(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
												 title varchar2 := null, disabled boolean := null) is
		v_text varchar2(1) character set value%charset := '';
	begin
		gv := tpl(true,
							'input',
							v_text,
							ac,
							st('type', 'button', 'name', name, 'title', title, 'disabled', b2c(nvl(disabled, gv_disabled))),
							prop('value', value));
	end;

	function input_submit(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
												title varchar2 := null, disabled boolean := null) return varchar2 character set value%charset is
		v_text varchar2(1) character set value%charset := '';
	begin
		return tpl(false,
							 'input',
							 v_text,
							 ac,
							 st('type', 'submit', 'name', name, 'title', title, 'disabled', b2c(nvl(disabled, gv_disabled))),
							 prop('value', value));
	end;

	procedure input_submit(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
												 title varchar2 := null, disabled boolean := null) is
		v_text varchar2(1) character set value%charset := '';
	begin
		gv := tpl(true,
							'input',
							v_text,
							ac,
							st('type', 'submit', 'name', name, 'title', title, 'disabled', b2c(nvl(disabled, gv_disabled))),
							prop('value', value));
	end;

	function input_reset(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
											 title varchar2 := null, disabled boolean := null) return varchar2 character set value%charset is
		v_text varchar2(1) character set value%charset := '';
	begin
		return tpl(false,
							 'input',
							 v_text,
							 ac,
							 st('type', 'reset', 'name', name, 'title', title, 'disabled', b2c(nvl(disabled, gv_disabled))),
							 prop('value', value));
	end;

	procedure input_reset(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
												title varchar2 := null, disabled boolean := null) is
		v_text varchar2(1) character set value%charset := '';
	begin
		gv := tpl(true,
							'input',
							v_text,
							ac,
							st('type', 'reset', 'name', name, 'title', title, 'disabled', b2c(nvl(disabled, gv_disabled))),
							prop('value', value));
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

	procedure select_option(text varchar2 character set any_cs, value varchar2 character set any_cs := null,
													selected boolean := null, ac st := null, disabled boolean := null, label varchar2 := null) is
	begin
		gv := tpl(true,
							'option',
							text,
							ac,
							st('selected', b2c(nvl(selected, gv_sv = value)), 'disabled', b2c(disabled), 'label', label),
							prop('value', value));
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

	----------------- ul/ol/li/dd/dl... ---------------------------

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

	procedure li(text varchar2 character set any_cs, ac st := null, value pls_integer := null, class varchar2 := null) is
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

	procedure dt(text varchar2 character set any_cs, ac st := null) is
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

	procedure dd(text varchar2 character set any_cs, ac st := null) is
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
				-- down one level
				ul_open;
			else
				li_close;
				for j in 1 .. v_level - v_pw_level loop
					-- return level
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

	procedure tree(cur sys_refcursor, text varchar2 character set any_cs, href varchar2 := null, class varchar2 := null) is
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

	procedure add_node(p_level pls_integer, p_text varchar2 character set any_cs, p_href varchar2 := null) is
	begin
		if p_level = gv_level + 1 then
			-- down one level
			if gv_type = 'menu' and p_level = 1 then
				ol_open;
			else
				ul_open;
			end if;
		else
			li_close;
			for j in 1 .. gv_level - p_level loop
				-- return level
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
			line('<br/>');
		end loop;
	end;

	procedure hr(sizep pls_integer := null, noshade boolean := null, ac st := null) is
	begin
		gv := tpl(true, 'hr', null, ac, st('size', sizep, 'noshade', b2c(noshade)));
	end;

	function img(src varchar2 := null, alt varchar2 character set any_cs := null, title varchar2 := null,
							 lowsrc varchar2 := null, ac st := null) return varchar2 is
		v_text varchar2(1) character set alt%charset := null;
	begin
		return tpl(false, 'img', v_text, ac, st('src', l(src), 'title', title, 'lowsrc', l(lowsrc)), prop('alt', alt));
	end;

	procedure img(src varchar2 := null, alt varchar2 character set any_cs := null, title varchar2 := null,
								lowsrc varchar2 := null, ac st := null) is
		v_text varchar2(1) character set alt%charset := null;
	begin
		gv := tpl(true, 'img', v_text, ac, st('src', l(src), 'title', title, 'lowsrc', l(lowsrc)), prop('alt', alt));
	end;

	procedure embed(src varchar2 := null, ac st := null, title varchar2 := null, pluginspage varchar2 := null) is
	begin
		gv := tpl(true, 'embed', null, ac, st('title', title, 'src', l(src), 'pluginspace', pluginspage));
	end;

	procedure object(text varchar2 character set any_cs := null, name varchar2 := null, ac st := null,
									 title varchar2 := null, classid varchar2 := null, codebase varchar2 := null,
									 data varchar2 character set any_cs := null, typep varchar2 := null,
									 alt varchar2 character set any_cs := null) is
		v_text varchar2(32000) character set alt%charset := text;
	begin
		gv := tpl(true,
							'object',
							v_text,
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
								 typep),
							prop('alt', alt));
	end;

	procedure object_open(name varchar2 := null, ac st := null, title varchar2 := null, classid varchar2 := null,
												codebase varchar2 := null, data varchar2 character set any_cs := null, typep varchar2 := null,
												alt varchar2 character set any_cs := null) is
		v_text varchar2(10) character set alt%charset := el_open;
	begin
		gv := tpl(true,
							'object',
							v_text,
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
								 typep),
							prop('alt', alt));
	end;

	procedure object_close is
	begin
		tag_close('object');
	end;

	procedure param(name varchar2, value varchar2 character set any_cs, ac st := null, valuetype varchar2 := null,
									typep varchar2 := null) is
		v_text varchar2(1) character set value%charset := null;
	begin
		gv := tpl(true, 'param', v_text, ac, st('name', name, 'valuetype', valuetype, 'type', typep), prop('value', value));
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

	procedure print(text varchar2 character set any_cs) is
	begin
		line(text);
	end;

	-- public
	procedure comment(text varchar2 character set any_cs) is
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

	function a(text varchar2 character set any_cs, href varchar2 := null, target varchar2 := null, ac st := null,
						 method varchar2 := null) return varchar2 character set text%charset is
	begin
		return tpl(false, 'a', text, ac, st('href', l(href, true), 'target', target, 'methods', method));
	end;

	procedure a(text varchar2 character set any_cs, href varchar2 := null, target varchar2 := null, ac st := null,
							method varchar2 := null) is
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
		assert(gv_tag_len > 0 and gv_tags(gv_tag_len) = 'frameset', 'frame tag must occur in frameset tag');
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

	procedure plsql_marker(unit varchar2, lineno pls_integer, text varchar2 character set any_cs := null) is
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
