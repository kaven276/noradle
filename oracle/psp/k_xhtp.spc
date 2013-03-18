create or replace package k_xhtp is

	pragma serially_reusable;

	nl constant varchar2(1) := chr(10);

	el_open constant varchar2(6) := '<tag>';

	el_close constant varchar2(6) := '</tag>';

	gv_xhtp boolean := false;

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

	-- basic output API
	procedure d(text varchar2 character set any_cs);
	procedure prn(text varchar2 character set any_cs);
	procedure prn(text in out nocopy clob character set any_cs);
	procedure line(text varchar2 character set any_cs := '');
	procedure l(txt varchar2, var st := null);
	function w(text varchar2 character set any_cs) return varchar2 character set text%charset;
	function ps(pat varchar2 character set any_cs, vals st, url boolean := null, ch char := ':') return varchar2 character set pat%charset;
	procedure ps(pat varchar2 character set any_cs, vals st, url boolean := null, ch char := ':');
	procedure blank_line(amount pls_integer := null);
	procedure print(text varchar2 character set any_cs);

	-- component css output API
	procedure set_css_prefix(prefix varchar2);
	procedure force_css_cv;
	procedure css(text varchar2, cv boolean := false);
	procedure lcss(text varchar2, cv boolean := false);
	procedure css(text varchar2, vals st, cv boolean := false);
	procedure lcss(text varchar2, vals st, cv boolean := false);
	procedure lcss_selector(texts varchar2);
	procedure lcss_selector(texts st);
	procedure lcss_rule(text varchar2, css_end boolean := false);
	procedure comp_css_link(setting boolean);

	-- tools APIs
	procedure split(p varchar2, sep varchar2 := ',');
	-- function split4tab(p varchar2, sep varchar2 := ',') return st;
	procedure join(sep varchar2 := ',');
	procedure split2(pairs varchar2, sep varchar2 := ';:');
	function tf(cond boolean, true_str varchar2 character set any_cs, false_str varchar2 character set any_cs := '')
		return varchar2 character set true_str%charset deterministic;

	procedure print_cgi_env;
	procedure go(url varchar2, vals st := null, info varchar2 := null);
	procedure comment(text varchar2 character set any_cs);
	-- output blank lines in xhtml

	--------------------------------------

	function is_dhc return boolean;
	procedure ensure_close;
	procedure http_header_close;
	procedure init;

	-----------------------

	-- param ac : stand for static bound parameters for attributes and inline-styles
	-- param da : stand for dynamic bound parameters for attributes
	function tag(name varchar2, text varchar2 character set any_cs, ac st := null, da st := null) return varchar2 character set text%charset;

	procedure tag(name varchar2, text varchar2 character set any_cs, ac st := null, da st := null);

	procedure tag_open(name varchar2, ac st := null, da st := null);

	procedure tag_close(name varchar2);

	--------
	-- top xhtml parts

	procedure use_vml;

	procedure set_compatible(value varchar2);

	procedure format_src(line_break varchar2 := nl);
	
	procedure set_check(value boolean);

	procedure doc_type(name varchar2 := 'transitional');

	procedure html_open(manifest varchar2 := null);

	procedure html_close;

	procedure head_open;

	procedure head_close;

	procedure body_open(ac st := null);

	procedure body_close;

	procedure html_head(title varchar2 character set any_cs default 'psp.web', links st := null, scripts st := null,
											body boolean default true);

	procedure html_tail;

	procedure h(files varchar2 := null, title varchar2 character set any_cs default 'psp.web', target varchar2 := null,
							href varchar2 := null, charset varchar2 := null, manifest varchar2 := '');

	-----------------------------------------------------------------

	-- none-display tags in head

	procedure title(text varchar2 character set any_cs);

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

	procedure script_text(text varchar2 character set any_cs);

	procedure js(text varchar2 character set any_cs);

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

	-- normal elements
	-- first 3 is text,id,class
	-- for block element, 4th parameter is align
	-- for inline element, 4th parameter is title
	-- 5th parameter is st type

	procedure pre_open(ac st := null);

	procedure pre_close;

	procedure hn(level pls_integer, text varchar2 character set any_cs := null, ac st := null);

	procedure p(text varchar2 character set any_cs := null, ac st := null);

	procedure div_open(ac st := null, id varchar2 := null);

	procedure div_close;

	procedure marquee_open(ac st := null, direction varchar2 := null, behavior varchar2 := null,
												 scrollamount pls_integer := null, scrolldelay pls_integer := null);

	procedure marquee_close;

	function span(text varchar2 character set any_cs := null, ac st := null, title varchar2 := null) return varchar2 character set text%charset;

	procedure span(text varchar2 character set any_cs := null, ac st := null, title varchar2 := null,
								 class varchar2 := null);

	function b(text varchar2 character set any_cs := null, ac st := null, title varchar2 := null) return varchar2 character set text%charset;

	procedure b(text varchar2 character set any_cs := null, ac st := null, title varchar2 := null, class varchar2 := null);

	-----------------------------------------------------------------

	procedure fieldset_open(ac st := null, id varchar2 := null);

	procedure fieldset_close;

	procedure legend(text varchar2 character set any_cs, ac st := null, title varchar2 := null);

	-----------------------------------------------------------------

	-- table parts

	procedure table_open(rules varchar2 := null, hv_ex char := null, cellspacing varchar2 := null,
											 cellpadding varchar2 := null, ac st := null, id varchar2 := null, switch_ex pls_integer := null,
											 cols_ex pls_integer := null);

	procedure table_close;

	procedure caption(text varchar2 character set any_cs, ac st := null, title varchar2 := null);

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

	procedure tr(text varchar2 character set any_cs, ac st := null, class varchar2 := null);

	function tr(text varchar2 character set any_cs, ac st := null) return varchar2 character set text%charset;

	procedure tr_close;

	procedure td(text varchar2 character set any_cs, ac st := null, title varchar2 := null, colspan pls_integer := null,
							 rowspan pls_integer := null, class varchar2 := null);

	function td(text varchar2 character set any_cs, ac st := null, title varchar2 := null, colspan pls_integer := null,
							rowspan pls_integer := null, class varchar2 := null) return varchar2 character set text%charset;

	procedure th(text varchar2 character set any_cs, ac st := null, title varchar2 := null, colspan pls_integer := null,
							 rowspan pls_integer := null, class varchar2 := null);

	function th(text varchar2 character set any_cs, ac st := null, title varchar2 := null, colspan pls_integer := null,
							rowspan pls_integer := null, class varchar2 := null) return varchar2 character set text%charset;

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

	-- form part
	-- first two parameter will be id, name

	procedure form_open(name varchar2 := null, action varchar2 := null, target varchar2 := null, ac st := null,
											method varchar2 := null, enctype varchar2 := null, readonly_ex boolean := null,
											disabled_ex boolean := null, id varchar2 := null);

	procedure form_close;

	procedure label(text varchar2 character set any_cs, ac st := null, title varchar2 := null, forp varchar2 := null);

	function label(text varchar2 character set any_cs, ac st := null, title varchar2 := null, forp varchar2 := null)
		return varchar2 character set text%charset;

	procedure label_open(ac st := null, title varchar2 := null, forp varchar2 := null);

	procedure label_close;

	procedure auto_input_class(flag boolean := true);

	function input_checkbox(name varchar2 := null, value varchar2 character set any_cs := null, checked boolean := false,
													ac st := null, title varchar2 := null, disabled boolean := null) return varchar2 character set value%charset;

	procedure input_checkbox(name varchar2 := null, value varchar2 character set any_cs := null,
													 label_ex varchar2 := null, checked boolean := false, ac st := null, title varchar2 := null,
													 disabled boolean := null);

	function input_radio(name varchar2 := null, value varchar2 character set any_cs := null, checked boolean := false,
											 ac st := null, title varchar2 := null, disabled boolean := null) return varchar2 character set value%charset;

	procedure input_radio(name varchar2 := null, value varchar2 character set any_cs := null, label_ex varchar2 := null,
												checked boolean := false, ac st := null, title varchar2 := null, disabled boolean := null);

	procedure input_hidden(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null);

	procedure input_keep(name varchar2);

	procedure input_keeps(name varchar2);

	procedure input_keep_all;

	function input_file(name varchar2 := null, ac st := null, title varchar2 := null, sizep pls_integer := null,
											disabled boolean := null) return varchar2;

	procedure input_file(name varchar2 := null, label_ex varchar2 := null, ac st := null, title varchar2 := null,
											 sizep pls_integer := null, disabled boolean := null);

	function input_password(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
													title varchar2 := null, sizep pls_integer := null, maxlength pls_integer := null,
													readonly boolean := null, disabled boolean := null) return varchar2 character set value%charset;

	procedure input_password(name varchar2 := null, value varchar2 character set any_cs := null,
													 label_ex varchar2 := null, ac st := null, title varchar2 := null, sizep pls_integer := null,
													 maxlength pls_integer := null, readonly boolean := null, disabled boolean := null);

	function input_text(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
											title varchar2 := null, sizep pls_integer := null, maxlength pls_integer := null,
											readonly boolean := null, disabled boolean := null) return varchar2 character set value%charset;

	procedure input_text(name varchar2 := null, value varchar2 character set any_cs := null, label_ex varchar2 := null,
											 ac st := null, title varchar2 := null, sizep pls_integer := null, maxlength pls_integer := null,
											 readonly boolean := null, disabled boolean := null);

	function textarea(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
										title varchar2 := null, rows pls_integer := null, cols pls_integer := null, readonly boolean := null,
										disabled boolean := null) return varchar2 character set value%charset;

	procedure textarea(name varchar2 := null, value varchar2 character set any_cs := null, label_ex varchar2 := null,
										 ac st := null, title varchar2 := null, rows pls_integer := null, cols pls_integer := null,
										 readonly boolean := null, disabled boolean := null);

	procedure button(name varchar2, value varchar2, text varchar2 character set any_cs, ac st := null,
									 title varchar2 := null, disabled boolean := null);

	function input_button(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
												title varchar2 := null, disabled boolean := null) return varchar2 character set value%charset;

	procedure input_button(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
												 title varchar2 := null, disabled boolean := null);

	function input_submit(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
												title varchar2 := null, disabled boolean := null) return varchar2 character set value%charset;

	procedure input_submit(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
												 title varchar2 := null, disabled boolean := null);

	function input_reset(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
											 title varchar2 := null, disabled boolean := null) return varchar2 character set value%charset;

	procedure input_reset(name varchar2 := null, value varchar2 character set any_cs := null, ac st := null,
												title varchar2 := null, disabled boolean := null);

	procedure select_open(name varchar2 := null, value_ex varchar2 := null, label_ex varchar2 := null, ac st := null,
												title varchar2 := null, sizep pls_integer := null, multiple boolean := false,
												disabled boolean := null);

	procedure select_close;

	procedure select_option(text varchar2 character set any_cs, value varchar2 character set any_cs := null,
													selected boolean := null, ac st := null, disabled boolean := null, label varchar2 := null);

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

	-- ul/ol/li/dd/dl ...

	procedure ul_open(ac st := null, id varchar2 := null);

	procedure ul_close;

	procedure ol_open(ac st := null, id varchar2 := null);

	procedure ol_close;

	procedure li(text varchar2 character set any_cs, ac st := null, value pls_integer := null, class varchar2 := null);

	procedure li_open(ac st := null, value pls_integer := null, class varchar2 := null);

	procedure li_close;

	procedure dl_open(ac st := null, id varchar2 := null);
	procedure dl_close;

	procedure dt(text varchar2 character set any_cs, ac st := null);

	procedure dt_open(ac st := null);
	procedure dt_close;

	procedure dd(text varchar2 character set any_cs, ac st := null);
	procedure dd_open(ac st := null);
	procedure dd_close;

	procedure tree(cur sys_refcursor);

	procedure tree(cur sys_refcursor, text varchar2 character set any_cs, href varchar2 := null, class varchar2 := null);

	procedure open_nodes(p_type varchar2);

	procedure close_nodes;

	procedure add_node(p_level pls_integer, p_text varchar2 character set any_cs, p_href varchar2 := null);

	-----------------------------------------------------------------

	procedure br(count_ex pls_integer := 1);

	procedure hr(sizep pls_integer := null, noshade boolean := null, ac st := null);

	function img(src varchar2 := null, alt varchar2 character set any_cs := null, title varchar2 := null,
							 lowsrc varchar2 := null, ac st := null) return varchar2;

	procedure img(src varchar2 := null, alt varchar2 character set any_cs := null, title varchar2 := null,
								lowsrc varchar2 := null, ac st := null);

	procedure object(text varchar2 character set any_cs := null, name varchar2 := null, ac st := null,
									 title varchar2 := null, classid varchar2 := null, codebase varchar2 := null,
									 data varchar2 character set any_cs := null, typep varchar2 := null,
									 alt varchar2 character set any_cs := null);

	procedure object_open(name varchar2 := null, ac st := null, title varchar2 := null, classid varchar2 := null,
												codebase varchar2 := null, data varchar2 character set any_cs := null, typep varchar2 := null,
												alt varchar2 character set any_cs := null);

	procedure object_close;

	procedure param(name varchar2, value varchar2 character set any_cs, ac st := null, valuetype varchar2 := null,
									typep varchar2 := null);

	procedure embed(src varchar2 := null, ac st := null, title varchar2 := null, pluginspage varchar2 := null);

	procedure xml(id varchar2, src varchar2);

	procedure xml_open(id varchar2, ac st := null);

	procedure xml_close;

	-----------------------------------------------------------------

	-- link
	function a(text varchar2 character set any_cs, href varchar2 := null, target varchar2 := null, ac st := null,
						 method varchar2 := null) return varchar2 character set text%charset;
	--pragma restrict_references(a, wnds, rnds);

	procedure a(text varchar2 character set any_cs, href varchar2 := null, target varchar2 := null, ac st := null,
							method varchar2 := null);

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

	-- mark the position in plsql code source
	procedure plsql_marker(unit varchar2, lineno pls_integer, text varchar2 character set any_cs := null);
	-- sub component start marker
	procedure plsql_begin(unit varchar2, lineno pls_integer);

	-- sub conponent end marker
	procedure plsql_end(unit varchar2, lineno pls_integer);

end k_xhtp;
/
