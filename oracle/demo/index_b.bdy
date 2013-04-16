create or replace package body index_b is

	procedure frame is
	begin
		p.doc_type('frameset');
		p.html_open;
		p.head_open;
		p.title('PSP.WEB test/demo suite');
		p.head_close;
		p.frameset_open(cols => '280,*', frameborder => 'yes');
		p.frame('dir', 'dir', scrolling => 'true', ac => st('#border-right:1px solid gray;overflow-y:scroll;'));
		p.frame('page', 'page');
		p.frameset_close;
		p.html_close;
	end;

	procedure dir is
	begin
		p.h(target => 'page');
		p.dl_open;

		p.dt('ora_good_b');
		p.dd(p.a('introduce', 'ora_good_b.entry'));

		p.dt('basic_io_b');
		p.dd(p.a('req_info', 'basic_io_b.req_info'));
		p.dd(p.a('output', 'basic_io_b.output'));
		p.dd(p.a('parameters', 'basic_io_b.parameters'));

		p.dt('http_b');
		p.dd(p.a('gzip', 'http_b.gzip'));
		p.dd(p.a('chunked_transfer', 'http_b.chunked_transfer'));
		p.dd(p.a('long_job', 'http_b.long_job'));
		p.dd(p.a('content_type', 'http_b.content_type'));
		p.dd(p.a('refresh to self', 'http_b.refresh'));
		p.dd(p.a('refresh to other', 'http_b.refresh?to=index_b.page'));
		p.dd(p.a('content_md5', 'http_b.content_md5'));

		p.dt('html_b');
		p.dd(p.a('d', 'html_b.d'));
		p.dd(p.a('component_css?link=Y', 'html_b.component_css?link=Y'));
		p.dd(p.a('component_css?link=N', 'html_b.component_css?link=N'));
		p.dd(p.a('regen_page', 'html_b.regen_page'));
		p.dd(p.a('component', 'html_b.component'));
		p.dd(p.a('print_cgi_env', 'html_b.print_cgi_env'));
		p.dd(p.a('complex', 'html_b.complex'));

		p.dt('user_b(show processing)');
		p.dd(p.a('register', 'user_b.register'));

		p.dt('url_b');
		p.dd(p.a('d', 'url_b.d'));
		p.dd(p.a('proc1', 'url_b.proc1'));
		p.dd(p.a('proc2', 'url_b.proc2'));
		p.dd(p.a('./url_test1_b', './url_test1_b'));
		p.dd(p.a('./url_test2_b', './url_test2_b'));

		p.dt('charset_b');
		p.dd(p.a('form', 'charset_b.form'));

		p.dt('file_dl_b');
		p.dd(p.a('d', 'file_dl_b.d'));
		p.dd(p.a('text', 'file_dl_b.text'));
		p.dd(p.a('excel', 'file_dl_b.excel'));
		p.dd(p.a('word', 'file_dl_b.excel'));

		p.dt('post_file_b');
		p.dd(p.a('upload_form', 'post_file_b.upload_form'));
		p.dd(p.a('ajax_post', 'post_file_b.ajax_post'));

		p.dt('filter_b');
		p.dd(p.a('filter source', '=src_b.pack/k_filter'));
		p.dd(p.a('see_filter', 'filter_b.see_filter'));

		p.dt('auth_b');
		p.dd(p.a('basic', 'auth_b.basic'));
		p.dd(p.a('digest', 'auth_b.digest'));
		p.dd(p.a('cookie_gac', 'auth_b.cookie_gac'));
		p.dd(p.a('protected_page', 'auth_b.protected_page'));
		p.dd(p.a('basic_and_cookie', 'auth_b.basic_and_cookie'));

		p.dt('term_b');
		p.dd(p.a('setting_form', 'term_b.setting_form'));

		p.dt('error_b');
		p.dd(p.a('execute_with_error', 'error_b.execute_with_error'));
		p.dd(p.a('check_right', 'error_b.check_right'));
		p.dd(p.a('maybe_no_data', 'error_b.maybe_no_data'));
		p.dd(p.a('on_developing', 'error_b.on_developing'));
		p.dd(p.a('call_external', 'error_b.call_external'));

		p.dt('cache_b');
		p.dd(p.a('expires', 'cache_b.expires'));
		p.dd(p.a('last_modified', 'cache_b.last_modified'));
		p.dd(p.a('etag_md5', 'cache_b.etag_md5'));
		p.dd(p.a('report_by_hour', 'cache_b.report_by_hour'));

		p.dt('xml_page_b');
		p.dd(p.a('xmlgen_str', 'xml_page_b.xmlgen_str'));
		p.dd(p.a('xmlgen_cur', 'xml_page_b.xmlgen_cur'));
		p.dd(p.a('xmlgen_hier', 'xml_page_b.xmlgen_hier'));
		p.dd(p.a('sql_users', 'xml_page_b.sql_users'));
		p.dd(p.a('xml_users_css', 'xml_page_b.xml_users_css'));
		p.dd(p.a('xml_users_xsl_cli', 'xml_page_b.xml_users_xsl_cli'));

		p.dt('db_src_b');
		p.dd(p.a('example', 'db_src_b.example'));

		p.dl_close;
	end;

	procedure page is
	begin
		p.h;
		p.p('The left frame is entrance to all the test pages');
	end;

end index_b;
/
