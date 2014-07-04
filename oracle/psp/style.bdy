create or replace package body style is

	-- control if all css rule begin with ^ add vender prefix
	gv_force_css_cv boolean;
	-- set which vender prefix to add, like -webkit-,-o-,-ms-
	gv_css_prefix varchar2(4000);

	gv_1st_lcss boolean;
	gv_tagnl    varchar2(3) := chr(10);
	gv_ctx      varchar2(4000);

	-- control if use px() to scale length unit value
	gv_scale       boolean;
	gv_base_width  pls_integer;
	gv_css_width   pls_integer;
	gv_font_width  pls_integer;
	gv_round_limit pls_integer;

	procedure init_by_request is
	begin
		gv_force_css_cv := false;
		gv_css_prefix   := '';
		gv_scale        := false;
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

	procedure embed(tag varchar2) is
	begin
		if not output.prevent_flush('style.embed') then
			return;
		end if;
		if tag = '<style>' then
			pv.csslink := false;
			output.switch_css;
		elsif tag = '<link>' then
			pv.csslink := true;
			output.switch_css;
		else
			pv.csslink := null;
			raise_application_error(-20010, 'style.embed tag must be style or link!');
		end if;
	end;

	procedure prn(text varchar2) is
	begin
		-- output.css(text);
		pv.pg_css := pv.pg_css || text;
	end;

	-- private, scale all px length value
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

	/**
   1. url convert
   2. add vender prefix
   3. scale length value
  */
	procedure css
	(
		text varchar2,
		cv   boolean
	) is
		v_text varchar2(2000);
		v_pos1 pls_integer;
		v_pos2 pls_integer := 0;
	begin
		v_text := text;
		loop
			v_pos1 := instrb(text, 'url(', v_pos2 + 1);
			exit when v_pos1 <= 0;
			v_pos2 := instrb(v_text, ')', v_pos1 + 4);
			v_text := substrb(v_text, 1, v_pos1 + 3) || l(substrb(v_text, v_pos1 + 4, v_pos2 - v_pos1 - 4)) ||
								substrb(v_text, v_pos2);
		end loop;
		if cv or gv_force_css_cv then
			v_text := replace(v_text, '^', gv_css_prefix);
		end if;
		if gv_scale then
			px(v_text);
		end if;
		-- output.css(v_text || gv_tagnl);
		pv.pg_css := pv.pg_css || v_text || gv_tagnl;
	end;

	procedure css
	(
		text varchar2,
		vals st,
		cv   boolean
	) is
	begin
		css(t.ps(text, vals, ch => '$'), cv);
	end;

	procedure lcss_ctx(selector varchar2) is
	begin
		gv_ctx := selector;
	end;

	procedure lcss
	(
		text varchar2,
		cv   boolean
	) is
		v_pos pls_integer;
		v_pad varchar2(2) := ' ';
	begin
		-- format check
		if gv_1st_lcss then
			v_pad       := gv_tagnl || ' ';
			gv_1st_lcss := false;
		end if;
		v_pos := instr(text, '{');
		css(v_pad || gv_ctx || ' ' || regexp_replace(substr(text, 1, v_pos), ',\s*', ', ' || gv_ctx) ||
				regexp_replace(substr(text, v_pos + 1), chr(10) || '\s+', chr(10) || '  '),
				cv);
	end;

	procedure lcss
	(
		text varchar2,
		vals st,
		cv   boolean
	) is
	begin
		lcss(t.ps(text, vals, ch => '$'), cv);
	end;

	/** progressively set css, selector once and multiple rules
    procedure lcss_selector(texts varchar2)
    lcss_selector(texts st)
    lcss_rule(text varchar2, css_end boolean := false)
  */

	procedure lcss_selector(texts varchar2) is
		v st;
	begin
		t.split(v, texts, ',');
		lcss_selector(v);
	end;

	procedure lcss_selector(texts st) is
	begin
		for i in 1 .. texts.count - 1 loop
			css(' ' || gv_ctx || ' ' || texts(i) || ' ,');
		end loop;
		css(' ' || gv_ctx || ' ' || texts(texts.count) || ' {');
	end;

	procedure lcss_rule
	(
		text    varchar2,
		css_end boolean := false
	) is
	begin
		css('    ' || text);
		if css_end then
			css(' }');
		end if;
	end;

	procedure set_scale
	(
		base   pls_integer,
		actual pls_integer,
		font   pls_integer
	) is
	begin
		gv_scale      := true;
		gv_base_width := base;
		gv_css_width  := nvl(actual, gv_base_width);
		gv_font_width := nvl(font, gv_css_width);
	end;

	procedure comp_css_link(setting boolean) is
	begin
		if setting is null then
			pv.csslink := null;
		elsif output.prevent_flush('p.comp_css_link') then
			pv.csslink := setting;
		end if;
	end;

end style;
/
