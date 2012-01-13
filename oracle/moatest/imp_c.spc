create or replace package imp_c is

	procedure bookmark;

	procedure load_js;

	procedure new_grab(js_url varchar2);

	procedure add_page(page_url varchar2);

	procedure add_page
	(
		page_url varchar2,
		js_func  varchar2
	);

	procedure resp_begin;

	procedure resp_end;

end imp_c;
/

