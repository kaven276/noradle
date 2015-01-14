create or replace package body index_b is

	procedure frame is
	begin
		x.t('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">');
		x.o('<html>');
		x.o('<head>');
		x.p(' <title>', 'PSP.WEB test/demo suite');
		x.c('</head>');
		x.o('<frameset cols=:1,frameborder=yes>', st('280,*'));
		x.j(' <frame name=dir,scrolling=true,style=border-right:1px solid gray;overflow-y:scroll;>', '@b.dir');
		x.j(' <frame name=page>', '@b.page');
		x.c('</frameset>');
		x.c('</html>');
	end;

	procedure dir is
	begin
		pc.h(target => 'page');
		x.o('<dl>');
	
		x.p('<dt>', 'ora_good_b');
		x.p('<dd>', x.a('<a>', 'introduce', 'ora_good_b.entry'));
	
		x.p('<dt>', 'basic_io_b');
		x.p('<dd>', x.a('<a>', 'req_info', 'basic_io_b.req_info'));
		x.p('<dd>', x.a('<a>', 'output', 'basic_io_b.output'));
		x.p('<dd>', x.a('<a>', 'parameters', 'basic_io_b.parameters'));
		x.p('<dd>', x.a('<a>', 'keep_urlencoded', 'basic_io_b.keep_urlencoded'));
	
		x.p('<dt>', 'http_b');
		x.p('<dd>', x.a('<a>', 'gzip', 'http_b.gzip'));
		x.p('<dd>', x.a('<a>', 'chunked_transfer', 'http_b.chunked_transfer'));
		x.p('<dd>', x.a('<a>', 'long_job', 'http_b.long_job'));
		x.p('<dd>', x.a('<a>', 'content_type', 'http_b.content_type'));
		x.p('<dd>', x.a('<a>', 'refresh to self', 'http_b.refresh'));
		x.p('<dd>', x.a('<a>', 'refresh to other', 'http_b.refresh?to=index_b.page'));
		x.p('<dd>', x.a('<a>', 'content_md5', 'http_b.content_md5'));
	
		x.p('<dt>', 'html_b');
		x.p('<dd>', x.a('<a>', 'd', 'html_b.d'));
		x.p('<dd>', x.a('<a>', 'component_css?link=Y', 'html_b.component_css?link=Y'));
		x.p('<dd>', x.a('<a>', 'component_css?link=N', 'html_b.component_css?link=N'));
		x.p('<dd>', x.a('<a>', 'regen_page', 'html_b.regen_page'));
		x.p('<dd>', x.a('<a>', 'component', 'html_b.component'));
		x.p('<dd>', x.a('<a>', 'complex', 'html_b.complex'));
	
		x.p('<dt>', 'concise HTML API');
		x.p('<dd>', x.a('<a>', 'use tag', 'pg_test_b.use_tag'));
		x.p('<dd>', x.a('<a>', 'odd_even_switch', 'pg_test_b.odd_even_switch'));
		x.p('<dd>', x.a('<a>', 'multi', 'pg_test_b.multi'));
		x.p('<dd>', x.a('<a>', 'tree', 'pg_test_b.tree'));
		x.p('<dd>', x.a('<a>', 'form', 'pg_test_b.form'));
	
		x.p('<dt>', 'progressive HTML API');
		x.p('<dd>', x.a('<a>', 'alink demo', 'attr_tagp_demo_b.alink'));
	
		x.p('<dt>', 'css in HTML API(embeded or linked)');
		x.p('<dd>', x.a('<a>', 'basic', 'style_b.d'));
	
		x.p('<dt>', 'table list formating/printing');
		x.p('<dd>', x.a('<a>', 'for loop print', 'list_b.user_objects'));
		x.p('<dd>', x.a('<a>', 'multi.c print', 'list_b.user_objects_cur'));
		x.p('<dd>', x.a('<a>', 'sys_refcursor print', 'list_b.user_procedures'));
	
		x.p('<dt>', 'ul/li tree printing');
		x.p('<dd>', x.a('<a>', 'for loop print', 'pg_test_b.tree'));
		x.p('<dd>', x.a('<a>', 'sys_refcursor tree', 'tree_b.emp_hier_cur'));
		x.p('<dd>', x.a('<a>', 'add nodes tree', 'tree_b.emp_hier_nodes'));
		x.p('<dd>', x.a('<a>', 'add nodes by indent', 'tree_b.menu'));
	
		x.p('<dt>', 'HTML page layout');
		x.p('<dd>', x.a('<a>', 'form V/H layouts', 'layout_b.form'));
	
		x.p('<dt>', 'user_b(show processing)');
		x.p('<dd>', x.a('<a>', 'register', 'user_b.register'));
	
		x.p('<dt>', 'easy_url_b');
		x.p('<dd>', x.a('<a>', 'd', 'easy_url_b.d'));
		x.p('<dd>', x.a('<a>', 'proc1', 'easy_url_b.proc1'));
		x.p('<dd>', x.a('<a>', 'proc2', 'easy_url_b.proc2'));
		x.p('<dd>', x.a('<a>', './url_test1_b', './url_test1_b'));
		x.p('<dd>', x.a('<a>', './url_test2_b', './url_test2_b'));
	
		x.p('<dt>', 'charset_b');
		x.p('<dd>', x.a('<a>', 'form', 'charset_b.form'));
	
		x.p('<dt>', 'negotiation_b');
		x.p('<dd>', x.a('<a>', 'lang_versions', 'negotiation_b.languages_by_browser'));
	
		x.p('<dt>', 'file_dl_b');
		x.p('<dd>', x.a('<a>', 'd', 'file_dl_b.d'));
		x.p('<dd>', x.a('<a>', 'text', 'file_dl_b.text'));
		x.p('<dd>', x.a('<a>', 'excel', 'file_dl_b.excel'));
		x.p('<dd>', x.a('<a>', 'word', 'file_dl_b.excel'));
	
		x.p('<dt>', 'post_file_b');
		x.p('<dd>', x.a('<a>', 'upload_form', 'post_file_b.upload_form'));
		x.p('<dd>', x.a('<a>', 'ajax_post', 'post_file_b.ajax_post'));
		x.p('<dd>', x.a('<a>', 'media capture', 'media_b.file_image'));
	
		x.p('<dt>', 'filter_b');
		x.p('<dd>', x.a('<a>', 'filter source', '=src_b.pack?p=k_filter'));
		x.p('<dd>', x.a('<a>', 'see_filter', 'filter_b.see_filter'));
	
		x.p('<dt>', 'session_b');
		x.p('<dd>', x.a('<a>', 'session login', 'session_b.login_form'));
	
		x.p('<dt>', 'auth_b');
		x.p('<dd>', x.a('<a>', 'basic', 'auth_b.basic'));
		x.p('<dd>', x.a('<a>', 'digest', 'auth_b.digest'));
		x.p('<dd>', x.a('<a>', 'cookie_gac', 'auth_b.cookie_gac'));
		x.p('<dd>', x.a('<a>', 'protected_page', 'auth_b.protected_page'));
		x.p('<dd>', x.a('<a>', 'basic_and_cookie', 'auth_b.basic_and_cookie'));
	
		x.p('<dt>', 'term_b');
		x.p('<dd>', x.a('<a>', 'setting_form', 'term_b.setting_form'));
	
		x.p('<dt>', 'error_b');
		x.p('<dd>', x.a('<a>', 'execute_with_error', 'error_b.execute_with_error'));
		x.p('<dd>', x.a('<a>', 'check_right', 'error_b.check_right'));
		x.p('<dd>', x.a('<a>', 'maybe_no_data', 'error_b.maybe_no_data'));
		x.p('<dd>', x.a('<a>', 'on_developing', 'error_b.on_developing'));
		x.p('<dd>', x.a('<a>', 'call_external', 'error_b.call_external'));
	
		x.p('<dt>', 'cache_b');
		x.p('<dd>', x.a('<a>', 'expires', 'cache_b.expires'));
		x.p('<dd>', x.a('<a>', 'last_modified', 'cache_b.last_modified'));
		x.p('<dd>', x.a('<a>', 'etag_md5', 'cache_b.etag_md5'));
		x.p('<dd>', x.a('<a>', 'report_by_hour', 'cache_b.report_by_hour'));
	
		x.p('<dt>', 'xml_page_b');
		x.p('<dd>', x.a('<a>', 'xmlgen_str', 'xml_page_b.xmlgen_str'));
		x.p('<dd>', x.a('<a>', 'xmlgen_cur', 'xml_page_b.xmlgen_cur'));
		x.p('<dd>', x.a('<a>', 'xmlgen_hier', 'xml_page_b.xmlgen_hier'));
		x.p('<dd>', x.a('<a>', 'sql_users', 'xml_page_b.sql_users'));
		x.p('<dd>', x.a('<a>', 'xml_users_css', 'xml_page_b.xml_users_css'));
		x.p('<dd>', x.a('<a>', 'xml_users_xsl_cli', 'xml_page_b.xml_users_xsl_cli'));
	
		x.p('<dt', 'app modes');
		x.p('<dd>', x.a('<a target=_blank>', 'view packages', 'po_content_b.packages'));
		x.p('<dd>', x.a('<a target=_blank>', 'bootstrap', 'bootstrap_b.packages'));
		x.p('<dd>', x.a('<a target=_blank>', 'frameset container', 'po_frameset_b.main'));
		x.p('<dd>', x.a('<a target=_blank>', 'iframe container', 'po_iframe_b.main'));
		x.p('<dd>', x.a('<a target=_blank>', 'ajaxload containver', 'po_ajaxload_b.main'));
	
		x.p('<dt>', 'db_src_b');
		x.p('<dd>', x.a('<a>', 'example', 'db_src_b.example'));
	
		x.p('<dt>', 'proformance test');
		x.p('<dd>', x.a('<a>', 'css_prof_b', 'css_prof_b.main'));
	
		x.c('</dl>');
	end;

	procedure page is
	begin
		pc.h;
		x.p('<p>', 'The left frame is entrance to all the test pages');
	end;

end index_b;
/
