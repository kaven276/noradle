create or replace package psp_page_header_b is

	-- Author  : ADMINISTRATOR
	-- Created : 2009-10-22 19:39:03
	-- Purpose :

	procedure print(p_prog varchar2 := null);

	procedure linked_css(p_page varchar2);

	procedure linked_js(p_page varchar2);

	procedure edit_form(p_page varchar2);

	procedure edit_main_handler
	(
		p_page    varchar2,
		p_title   varchar2,
		p_anytext varchar2
	);

	procedure edit_css_handler
	(
		p_page varchar2,
		p_css  varchar2
	);

	procedure edit_js_handler
	(
		p_page varchar2,
		p_js   varchar2
	);

end psp_page_header_b;
/

