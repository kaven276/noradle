create or replace package style is

	-- init setting for every servlet execution
	procedure init_by_request;
	-- component css output API
	procedure embed(tag varchar2 := '<link>');
	-- raw css output
	procedure prn(text varchar2);

	-- global css with additional precompilations
	procedure set_css_prefix(prefix varchar2);
	procedure force_css_cv;
	procedure set_scale(base pls_integer, actual pls_integer := null, font pls_integer := null);

	procedure css(text varchar2, cv boolean := false);
	procedure css(text varchar2, vals st, cv boolean := false);

	-- localized css with all-in-one and progressive API
	procedure lcss_ctx(selector varchar2);
	procedure lcss(text varchar2, cv boolean := false);
	procedure lcss(text varchar2, vals st, cv boolean := false);
	procedure lcss_selector(texts varchar2);
	procedure lcss_selector(texts st);
	procedure lcss_rule(text varchar2, css_end boolean := false);

end style;
/
