create or replace package k_xhtp is

	pragma serially_reusable;

	nl constant varchar2(1) := chr(10);

	el_open constant varchar2(6) := '<tag>';

	el_close constant varchar2(6) := '</tag>';

	gv_xhtp boolean := false;

	dad_charset varchar2(30);
	mime_type   varchar2(100);

	gv_headers_str varchar2(200);

	function next_seq return varchar2;

	gv_count  pls_integer;
	gv_st     st;
	gv_texts  st;
	gv_values st;

	s     varchar2(4000);
	i     pls_integer;
	j     pls_integer;
	k     pls_integer;
	count pls_integer;
	scn   number := null;
	url   varchar2(4000);

	type pairs_t is ref cursor;

	gv_base_width  pls_integer;
	gv_css_width   pls_integer;
	gv_font_width  pls_integer;
	gv_scale       boolean := false;
	gv_round_limit pls_integer := 5;

	----------------------------------------------------------------

	procedure save_pointer;
	function appended return boolean;

	-- 简单原样输出
	procedure d(text varchar2);
	procedure prn(text varchar2);
	procedure prn(text in out nocopy clob);
	procedure set_css_prefix(prefix varchar2);
	procedure force_css_cv;
	procedure css(text varchar2, cv boolean := false);
	procedure lcss(text varchar2, cv boolean := false);
	procedure css(text varchar2, vals st, cv boolean := false);
	procedure lcss(text varchar2, vals st, cv boolean := false);
	procedure lcss_selector(texts varchar2);
	procedure lcss_selector(texts st);
	procedure lcss_rule(text varchar2, css_end boolean := false);

	procedure show_page;

	/*
  procedure range_replace
  (
    id      varchar2,
    pattern varchar2,
    value   varchar2
  );
  */

	-- 输出再换行
	procedure line(text varchar2 := '');

	procedure l(txt varchar2, var st := null);

	function w(text varchar2) return varchar2;

	function ps(pat varchar2, vals st, url boolean := null, ch char := ':') return varchar2;

	procedure ps(pat varchar2, vals st, url boolean := null, ch char := ':');

	procedure split(p varchar2, sep varchar2 := ',');

	-- function split4tab(p varchar2, sep varchar2 := ',') return st;

	procedure join(sep varchar2 := ',');

	procedure split2(pairs varchar2, sep varchar2 := ';:');

	function tf(cond boolean, true_str varchar2, false_str varchar2 := '') return varchar2 deterministic;

	procedure print_cgi_env;

	procedure go(url varchar2, vals st := null, info varchar2 := null);
	-- 注释
	procedure comment(text varchar2);

	-- xhtml 源码中输出空行
	procedure blank_line(amount pls_integer := null);

	-- 纯文本
	procedure print(text varchar2);

	--------------------------------------

	-- 当 dhc 层还没有开始输出 body open 时为真
	function is_dhc return boolean;

	-- 当 dhc 页面没有结束 body/html 标签时会自动补齐
	procedure ensure_close;

	--------------------------------------

	-- 结束 http 头部
	procedure http_header_close;

	-- 清空已经输出的内容
	procedure init;

	-----------------------

	function tag(name varchar2, text varchar2, ac st := null,
							 -- stand for static bound parameters for attributes and inline-styles
							 da st := null
							 -- stand for dynamic bound parameters for attributes
							 ) return varchar2;

	procedure tag(name varchar2, text varchar2, ac st := null, da st := null);

	procedure tag_open(name varchar2, ac st := null, da st := null);

	procedure tag_close(name varchar2);

	--------
	-- 本段为 xhtml 必须有的几个部分

	procedure use_vml;

	procedure set_compatible(value varchar2);

	procedure format_src;

	procedure css_link(start_size pls_integer := 512);

	procedure doc_type(name varchar2 := 'transitional');

	procedure html_open(manifest varchar2 := null);

	procedure html_close;

	procedure head_open;

	procedure head_close;

	procedure body_open(ac st := null);

	procedure body_close;

	procedure html_head(title varchar2 default 'psp.web', links st := null, scripts st := null, body boolean default true);

	procedure html_tail;

	procedure h(files varchar2 := null, title varchar2 default 'psp.web', target varchar2 := null, href varchar2 := null,
							charset varchar2 := null, manifest varchar2 := '');

	-----------------------------------------------------------------

	-- 本段为能够出现在 head 中，不作为显示元素的部分

	procedure title(text varchar2);

	--set_base已封装在head_open中，此处只为未使用k_xhtp的程序提供API
	procedure base(href varchar2 := null, target varchar2 := null);

	procedure meta_init;

	procedure meta(content varchar2, http_equiv varchar2 default null, name varchar2 default null);

	procedure meta_http_equiv(http_equiv varchar2, content varchar2);

	procedure meta_name(name varchar2, content varchar2);

	---------------------

	procedure link(href varchar2, ac st := null);

	procedure links(hrefs varchar2, ac st := null);

	procedure style_open(ac st := null);

	procedure style_close;

	------------------

	procedure script_text(text varchar2);

	procedure js(text varchar2);

	procedure script(src varchar2, ac st := null);

	procedure scripts(src varchar2, ac st := null);

	procedure script_open(ac st := null);

	procedure script_close;

	------------------

	procedure hta(ac st := null, id varchar2 := null, applicationname varchar2 := null, version varchar2 := null,
								caption boolean := null, sysmenu boolean := null, maximizebutton boolean := null,
								minimizebutton boolean := null, contextmenu boolean := null, navigable boolean := null,
								selection boolean := null, showintaskbar boolean := null, singleinstance boolean := null,
								windowstate varchar2 := null, scroll varchar2 := null, icon varchar2 := null, border varchar2 := null,
								borderstyle varchar2 := null, innerborder boolean := null, scrollflat boolean := null);

	-----------------------------------------------------------------

	-- 本段为一般的元素 div/span hn
	-- 前三个元素均为 text,id,class
	-- 对于块元素(一般内部有多行显示) 第四个参数是 align
	-- 对于行元素(一般显示在一行中的元素) 第四个参数是 title
	-- 第五个参数为 st 类型，随意显示其他各种属性 attributes
	-- 第六个参数为 st 类型，随意显示其他各种 inline styles

	procedure pre_open(ac st := null);

	procedure pre_close;

	procedure hn(level pls_integer, text varchar2 := null, ac st := null);

	procedure p(text varchar2 := null, ac st := null);

	procedure div_open(ac st := null, id varchar2 := null);

	procedure div_close;

	procedure marquee_open(ac st := null, direction varchar2 := null, behavior varchar2 := null,
												 scrollamount pls_integer := null, scrolldelay pls_integer := null);

	procedure marquee_close;

	function span(text varchar2 := null, ac st := null, title varchar2 := null) return varchar2;

	procedure span(text varchar2 := null, ac st := null, title varchar2 := null, class varchar2 := null);

	function b(text varchar2 := null, ac st := null, title varchar2 := null) return varchar2;

	procedure b(text varchar2 := null, ac st := null, title varchar2 := null, class varchar2 := null);

	-----------------------------------------------------------------

	procedure fieldset_open(ac st := null, id varchar2 := null);

	procedure fieldset_close;

	procedure legend(text varchar2, ac st := null, title varchar2 := null);

	-----------------------------------------------------------------

	-- 本段为 table 及其内部各对象的输出

	procedure table_open(rules varchar2 := null, hv_ex char := null, cellspacing varchar2 := null,
											 cellpadding varchar2 := null, ac st := null, id varchar2 := null, switch_ex pls_integer := null,
											 cols_ex pls_integer := null);

	procedure table_close;

	procedure caption(text varchar2, ac st := null, title varchar2 := null);

	procedure col(class varchar2 := null, align varchar2 := null, width varchar2 := null, span pls_integer := null,
								ac st := null);

	procedure cols(classes st);

	procedure cols(classes varchar2, sep varchar2 := ',');

	procedure colgroup(class varchar2 := null, align varchar2 := null, width varchar2 := null, span pls_integer := null,
										 ac st := null);

	procedure colgroup_open(class varchar2 := null, align varchar2 := null, width varchar2 := null,
													span pls_integer := null, ac st := null);

	procedure colgroup_close;

	procedure thead_open;

	procedure thead_close;

	procedure tbody_open(ac st := null, title varchar2 := null, class varchar2 := null);

	procedure tbody_close;

	procedure tfoot_open;

	procedure tfoot_close;

	procedure thead_tr_td_open(colspan number := null);

	procedure thead_tr_td_close;

	procedure tbody_tr_td_open(colspan number := null);

	procedure tbody_tr_td_close;

	procedure tfoot_tr_td_open(colspan number := null);

	procedure tfoot_tr_td_close;

	procedure table_tr_td_open;

	procedure table_tr_td_close;

	procedure tr_open(ac st := null, class varchar2 := null);

	procedure tr(text varchar2, ac st := null, class varchar2 := null);

	function tr(text varchar2, ac st := null) return varchar2;

	procedure tr_close;

	procedure td(text varchar2, ac st := null, title varchar2 := null, colspan pls_integer := null,
							 rowspan pls_integer := null, class varchar2 := null);

	function td(text varchar2, ac st := null, title varchar2 := null, colspan pls_integer := null,
							rowspan pls_integer := null, class varchar2 := null) return varchar2;

	procedure th(text varchar2, ac st := null, title varchar2 := null, colspan pls_integer := null,
							 rowspan pls_integer := null, class varchar2 := null);

	function th(text varchar2, ac st := null, title varchar2 := null, colspan pls_integer := null,
							rowspan pls_integer := null, class varchar2 := null) return varchar2;

	procedure ths(texts st);

	procedure tds(texts st);

	procedure ths(texts varchar2, sep varchar2 := ',');

	procedure tds(texts varchar2, sep varchar2 := ',');

	function ths(texts st) return varchar2;

	function tds(texts st) return varchar2;

	function ths(texts varchar2, sep varchar2 := ',') return varchar2;

	function tds(texts varchar2, sep varchar2 := ',') return varchar2;

	procedure pair(left varchar2, right varchar2);

	-----------------------------------------------------------------

	-- 本部分均为表单相关的
	-- 前两个参数均为 id, name

	procedure form_open(name varchar2 := null, action varchar2 := null, target varchar2 := null, ac st := null,
											method varchar2 := null, enctype varchar2 := null, readonly_ex boolean := null,
											disabled_ex boolean := null, id varchar2 := null);

	procedure form_close;

	procedure label(text varchar2, ac st := null, title varchar2 := null, forp varchar2 := null);

	function label(text varchar2, ac st := null, title varchar2 := null, forp varchar2 := null) return varchar2;

	procedure label_open(ac st := null, title varchar2 := null, forp varchar2 := null);

	procedure label_close;

	procedure auto_input_class(flag boolean := true);

	function input_checkbox(name varchar2 := null, value varchar2 := null, checked boolean := false, ac st := null,
													title varchar2 := null, disabled boolean := null) return varchar2;

	procedure input_checkbox(name varchar2 := null, value varchar2 := null, label_ex varchar2 := null,
													 checked boolean := false, ac st := null, title varchar2 := null, disabled boolean := null);

	function input_radio(name varchar2 := null, value varchar2 := null, checked boolean := false, ac st := null,
											 title varchar2 := null, disabled boolean := null) return varchar2;

	procedure input_radio(name varchar2 := null, value varchar2 := null, label_ex varchar2 := null,
												checked boolean := false, ac st := null, title varchar2 := null, disabled boolean := null);

	procedure input_hidden(name varchar2 := null, value varchar2 := null, ac st := null);

	procedure input_keep(name varchar2);

	procedure input_keeps(name varchar2);

	procedure input_keep_all;

	function input_file(name varchar2 := null, ac st := null, title varchar2 := null, sizep pls_integer := null,
											disabled boolean := null) return varchar2;

	procedure input_file(name varchar2 := null, label_ex varchar2 := null, ac st := null, title varchar2 := null,
											 sizep pls_integer := null, disabled boolean := null);

	function input_password(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
													sizep pls_integer := null, maxlength pls_integer := null, readonly boolean := null,
													disabled boolean := null) return varchar2;

	procedure input_password(name varchar2 := null, value varchar2 := null, label_ex varchar2 := null, ac st := null,
													 title varchar2 := null, sizep pls_integer := null, maxlength pls_integer := null,
													 readonly boolean := null, disabled boolean := null);

	function input_text(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
											sizep pls_integer := null, maxlength pls_integer := null, readonly boolean := null,
											disabled boolean := null) return varchar2;

	procedure input_text(name varchar2 := null, value varchar2 := null, label_ex varchar2 := null, ac st := null,
											 title varchar2 := null, sizep pls_integer := null, maxlength pls_integer := null,
											 readonly boolean := null, disabled boolean := null);

	function textarea(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
										rows pls_integer := null, cols pls_integer := null, readonly boolean := null,
										disabled boolean := null) return varchar2;

	procedure textarea(name varchar2 := null, value varchar2 := null, label_ex varchar2 := null, ac st := null,
										 title varchar2 := null, rows pls_integer := null, cols pls_integer := null,
										 readonly boolean := null, disabled boolean := null);

	procedure button(name varchar2, value varchar2, text varchar2, ac st := null, title varchar2 := null,
									 disabled boolean := null);

	function input_button(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
												disabled boolean := null) return varchar2;

	procedure input_button(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
												 disabled boolean := null);

	function input_submit(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
												disabled boolean := null) return varchar2;

	procedure input_submit(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
												 disabled boolean := null);

	function input_reset(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
											 disabled boolean := null) return varchar2;

	procedure input_reset(name varchar2 := null, value varchar2 := null, ac st := null, title varchar2 := null,
												disabled boolean := null);

	procedure select_open(name varchar2 := null, value_ex varchar2 := null, label_ex varchar2 := null, ac st := null,
												title varchar2 := null, sizep pls_integer := null, multiple boolean := false,
												disabled boolean := null);

	procedure select_close;

	procedure select_option(text varchar2, value varchar2 := null, selected boolean := null, ac st := null,
													disabled boolean := null, label varchar2 := null);

	procedure optgroup(label varchar2 := null, ac st := null, disabled boolean := null);

	----------------------------------------

	function fill_pairs(cur pairs_t) return number;

	procedure fill_pairs(cur pairs_t);

	procedure input_radios(name varchar2, sv varchar2 := null, label_ex varchar2 := null, ac st := null,
												 null_ex varchar2 := null, disabled boolean := null);

	procedure input_checkboxes(name varchar2, svs in st := st(), label_ex varchar2 := null, ac st := null,
														 disabled boolean := null);

	procedure select_single(name varchar2 := null, sv varchar2 := null, label_ex varchar2 := null, ac st := null,
													null_ex varchar2 := null, title varchar2 := null, sizep pls_integer := null,
													disabled boolean := null);

	procedure select_multiple(name varchar2 := null, svs st := null, label_ex varchar2 := null, ac st := null,
														title varchar2 := null, sizep pls_integer := null, disabled boolean := null);

	procedure input_list(tag varchar2, name varchar2 := null, svs st := null, label_ex varchar2 := null, ac st := null,
											 disabled boolean := null);

	function is_null(value varchar2) return boolean;

	-----------------------------------------------------------------

	-- ul/ol/li/dd/dl 等等

	procedure ul_open(ac st := null, id varchar2 := null);

	procedure ul_close;

	procedure ol_open(ac st := null, id varchar2 := null);

	procedure ol_close;

	procedure li(text varchar2, ac st := null, value pls_integer := null, class varchar2 := null);

	procedure li_open(ac st := null, value pls_integer := null, class varchar2 := null);

	procedure li_close;

	procedure dl_open(ac st := null, id varchar2 := null);
	procedure dl_close;

	procedure dt(text varchar2, ac st := null);

	procedure dt_open(ac st := null);
	procedure dt_close;

	procedure dd(text varchar2, ac st := null);
	procedure dd_open(ac st := null);
	procedure dd_close;

	procedure tree(cur sys_refcursor);

	procedure tree(cur sys_refcursor, text varchar2, href varchar2 := null, class varchar2 := null);

	procedure open_nodes(p_type varchar2);

	procedure close_nodes;

	procedure add_node(p_level pls_integer, p_text varchar2, p_href varchar2 := null);

	-----------------------------------------------------------------

	procedure br(count_ex pls_integer := 1);

	procedure hr(sizep pls_integer := null, noshade boolean := null, ac st := null);

	function img(src varchar2 := null, alt varchar2 := null, title varchar2 := null, lowsrc varchar2 := null,
							 ac st := null) return varchar2;

	procedure img(src varchar2 := null, alt varchar2 := null, title varchar2 := null, lowsrc varchar2 := null,
								ac st := null);

	procedure object(text varchar2 := null, name varchar2 := null, ac st := null, title varchar2 := null,
									 classid varchar2 := null, codebase varchar2 := null, data varchar2 := null, typep varchar2 := null,
									 alt varchar2 := null);

	procedure object_open(name varchar2 := null, ac st := null, title varchar2 := null, classid varchar2 := null,
												codebase varchar2 := null, data varchar2 := null, typep varchar2 := null, alt varchar2 := null);

	procedure object_close;

	procedure param(name varchar2, value varchar2, ac st := null, valuetype varchar2 := null, typep varchar2 := null);

	procedure embed(src varchar2 := null, ac st := null, title varchar2 := null, pluginspage varchar2 := null);

	procedure xml(id varchar2, src varchar2);

	procedure xml_open(id varchar2, ac st := null);

	procedure xml_close;

	-----------------------------------------------------------------

	-- 链接
	function a(text varchar2, href varchar2 := null, target varchar2 := null, ac st := null, method varchar2 := null)
		return varchar2;
	--pragma restrict_references(a, wnds, rnds);

	procedure a(text varchar2, href varchar2 := null, target varchar2 := null, ac st := null, method varchar2 := null);

	----------------------------------------------------------------

	procedure frameset_open(name varchar2 := null, rows varchar2 := null, cols varchar2 := null, ac st := null,
													frameborder varchar2 := null, framespacing varchar2 := null, bordercolor varchar2 := null);

	procedure frameset_close;

	procedure frame(name varchar2 := null, src varchar2 := null, ac st := null, frameborder varchar2 := null,
									scrolling varchar2 := null, noresize boolean := null);

	-- iframe
	procedure iframe(name varchar2 := null, src varchar2 := null, ac st := null, frameborder varchar2 := null,
									 scrolling varchar2 := null);

	--------------------------------------------------------------------------

	procedure cfg_init;
	procedure cfg_add(class varchar2, label varchar2, align varchar2 := 'center', width varchar2 := null,
										style varchar2 := null, format varchar2 := null);
	procedure cfg_cols;
	procedure cfg_ths;
	procedure cfg_cols_thead;
	procedure cfg_content(cur in out nocopy sys_refcursor, fmt_date varchar2 := null, group_size pls_integer := null);

	-- 标注针对本注释标签的对应的 plsql 源码位置
	procedure plsql_marker(unit varchar2, lineno pls_integer, text varchar2 := null);

	-- sub component start marker
	procedure plsql_begin(unit varchar2, lineno pls_integer);

	-- sub conponent end marker
	procedure plsql_end(unit varchar2, lineno pls_integer);

end k_xhtp;
/

