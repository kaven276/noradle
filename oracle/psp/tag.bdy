create or replace package body tag is

	function w
	(
		text varchar2,
		tag  varchar2 := 'b'
	) return varchar2 is
	begin
		return regexp_replace(text, '(.)', replace('<*>\1</*>', '*', tag));
	end;

	function r
	(
		text varchar2,
		dyna varchar2
	) return varchar2 is
	begin
		return replace(text, '@', dyna);
	end;

	function b2c
	(
		value boolean,
		attr  varchar2
	) return varchar2 is
	begin
		if value then
			return attr || '';
		else
			return '';
		end if;
	end;

	function checked(value boolean) return varchar2 is
	begin
		return b2c(value, 'checked');
	end;

	function selected(value boolean) return varchar2 is
	begin
		return b2c(value, 'selected');
	end;

	function disabled(value boolean) return varchar2 is
	begin
		return b2c(value, 'disabled');
	end;

	function readonly(value boolean) return varchar2 is
	begin
		return b2c(value, 'readonly');
	end;

	function defer(value boolean) return varchar2 is
	begin
		return b2c(value, 'defer');
	end;

	function async(value boolean) return varchar2 is
	begin
		return b2c(value, 'async');
	end;

	function base
	(
		tag   varchar2,
		para  st := null,
		text  varchar2 character set any_cs,
		extra varchar2 := ''
	) return nvarchar2 is
		p1      pls_integer; -- <
		p2      pls_integer; -- #
		p3      pls_integer; -- .
		p4      pls_integer; -- ' '
		p5      pls_integer; -- >
		v_tag   varchar2(60);
		v_id    varchar2(60);
		v_cls   varchar2(4000);
		v_attrs varchar2(4000);
		v_head  varchar2(4000);
	begin
		p1 := instrb(tag, '<');
		p4 := nullif(instrb(tag, ' ', p1 + 1), 0);
		p2 := nullif(instrb(tag, '#', p1 + 1), 0);
		if p2 > p4 then
			p2 := null;
		end if;
		p3 := nullif(instrb(tag, '.', coalesce(p2, p1) + 1), 0);
		if p3 > p4 then
			p3 := null;
		end if;
	
		p5 := lengthb(tag);
	
		v_tag := nvl(substrb(tag, p1 + 1, coalesce(p2, p3, p4, p5) - p1 - 1), 'div');
		if p2 is not null then
			v_id := ' id="' || substrb(tag, p2 + 1, coalesce(p3, p4, p5) - p2 - 1) || '"';
		end if;
		if p3 is not null then
			v_cls := ' class="' || replace(substrb(tag, p3 + 1, coalesce(p4, p5) - p3 - 1), '.', ' ') || '"';
		end if;
		if p4 is not null then
			v_attrs := ' ' ||
								 replace(replace(replace(substrb(tag, p4 + 1, p5 - p4 - 1), '=', '="'), ',', '" '), '^', 'data-') ||
								 k_type_tool.tf(instrb(tag, '=', p4 + 1) > 0, '"', '');
		end if;
	
		if para is null then
			v_head := v_tag || v_id || v_cls || v_attrs;
		else
			v_head := k_type_tool.ps(v_tag || v_id || v_cls || v_attrs, para, ':');
		end if;
	
		if text = chr(0) then
			return '<' || v_head || extra || '/>';
		elsif text = '<>' then
			sts.stack := '</' || v_tag || '>' || sts.stack;
			return '<' || v_head || extra || '>';
		else
			return n'<' || v_head || extra || '>' || text || '</' || v_tag || '>';
		end if;
	
	end;

	procedure o
	(
		tag  varchar2,
		para st := st()
	) is
	begin
		bdy.line(base(tag, para, '<>'));
	end;

	procedure c(tag varchar2) is
		v_tag varchar2(30) := ltrim(tag);
		v_err varchar2(4000);
	begin
	
		if substrb(sts.stack, 1, lengthb(v_tag)) != v_tag then
			v_err := 'tag open/close mismatch for ' || sts.stack || ',' || v_tag;
			raise_application_error(-20000, v_err);
		else
			sts.stack := substrb(sts.stack, lengthb(v_tag) + 1);
		end if;
	
		bdy.line(v_tag);
	end;

	function p
	(
		tag   varchar2,
		inner varchar2 character set any_cs := '',
		para  st := null,
		cut   boolean := false
	) return nvarchar2 is
	begin
		if cut then
			return '';
		end if;
		return base(tag, para, inner);
	end;

	procedure p
	(
		tag   varchar2,
		inner varchar2 character set any_cs := '',
		para  st := null,
		cut   boolean := false
	) is
	begin
		if cut then
			return;
		end if;
		bdy.line(base(tag, para, inner));
	end;

	function s
	(
		tag  varchar2,
		para st := null,
		cut  boolean := false
	) return varchar2 is
	begin
		if cut then
			return '';
		end if;
		return base(tag, para, chr(0));
	end;

	procedure s
	(
		tag  varchar2,
		para st := null,
		cut  boolean := false
	) is
	begin
		if cut then
			return;
		end if;
		bdy.line(base(tag, para, chr(0)));
	end;

	procedure f
	(
		tg     varchar2,
		action varchar2,
		para   st := st()
	) is
	begin
		bdy.line(base(tg, para, '<>', ' action="' || url(action) || '"'));
	end;

	function a
	(
		tg   varchar2,
		text varchar2 character set any_cs,
		href varchar2,
		para st := null,
		cut  boolean := false
	) return nvarchar2 is
	begin
		if cut then
			return '';
		end if;
		return base(tg, para, text, ' href="' || url(href) || '"');
	end;

	procedure a
	(
		tg   varchar2,
		text varchar2 character set any_cs,
		href varchar2,
		para st := null,
		cut  boolean := false
	) is
	begin
		if cut then
			return;
		end if;
		bdy.line(base(tg, para, text, ' href="' || url(href) || '"'));
	end;

	function v
	(
		tg    varchar2,
		value varchar2,
		para  st := null
	) return varchar2 is
	begin
		return tag.base(tg, para, chr(0), ' value="' || value || '"');
	end;

	procedure v
	(
		tg    varchar2,
		value varchar2,
		para  st := null
	) is
	begin
		bdy.line(base(tg, para, chr(0), ' value="' || value || '"'));
	end;

	function i
	(
		tg   varchar2,
		src  varchar2,
		para st := null
	) return varchar2 is
	begin
		return tag.base(tg, para, chr(0), ' src="' || url(src) || '"');
	end;

	procedure i
	(
		tg   varchar2,
		src  varchar2,
		para st := null
	) is
	begin
		bdy.line(base(tg, para, chr(0), ' src="' || url(src) || '"'));
	end;

	function t
	(
		text varchar2 character set any_cs,
		para st := null,
		cut  boolean := false
	) return varchar2 is
	begin
		if cut then
			return '';
		end if;
		if para is null then
			return text;
		else
			return k_type_tool.ps(text, para, ':');
		end if;
	end;

	procedure t
	(
		text   varchar2 character set any_cs,
		para   st := null,
		indent boolean := true,
		cut    boolean := false
	) is
	begin
		if cut then
			return;
		end if;
		if para is null then
			if not indent then
				bdy.line(text);
			else
				bdy.line(ltrim(text));
			end if;
		else
			if not indent then
				bdy.line(k_type_tool.ps(text, para, ':'));
			else
				bdy.line(k_type_tool.ps(ltrim(text), para, ':'));
			end if;
		end if;
	end;

	function e(text varchar2 character set any_cs) return varchar2 is
	begin
		return replace(replace(text, '<', '&lt;'), '>', '&gt;');
	end;

	procedure j
	(
		tg   varchar2,
		src  varchar2,
		para st := null
	) is
	begin
		bdy.line(base(tg, para, '', ' src="' || url(src) || '"'));
	end;

	procedure l
	(
		tg   varchar2,
		href varchar2,
		rel  varchar2 := null,
		para st := null
	) is
	begin
		bdy.line(base(tg, para, chr(0), ' href="' || url(href) || '" rel="' || nvl(rel, 'stylesheet') || '"'));
	end;

	procedure b
	(
		tg   varchar2,
		href varchar2 := '^',
		para st := null
	) is
	begin
		bdy.line(base(tg, para, chr(0), ' href="' || url(href) || '"'));
	end;

	function stack return varchar2 is
	begin
		return sts.stack;
	end;

end tag;
/
