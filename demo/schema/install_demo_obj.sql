-----------------------------------------------------
-- Export file for user DEMO                       --
-- Created by Administrator on 2013-4-18, 11:16:42 --
-----------------------------------------------------

set define off
set echo on

whenever sqlerror continue
prompt
prompt Creating table TERM_T
prompt =====================
prompt
@@term_t.tab
prompt
prompt Creating table USER_T
prompt =====================
prompt
@@user_t.tab
prompt
prompt Creating table PASSWD_HIS_T
prompt =====================
prompt
@@passwd_his_t.tab
prompt
prompt Creating table EMP_T
prompt ==========================
prompt
@@emp_t.tab
whenever sqlerror exit

@@pc.spc
@@pc.bdy

prompt
prompt Creating package DEFAULT_B
prompt ==========================
prompt
@@default_b.spc
@@default_b.bdy

prompt
prompt Creating package SRC_B
prompt ======================
prompt
@@src_b.spc
@@src_b.bdy

prompt
prompt Creating package INDEX_B
prompt ========================
prompt
@@index_b.spc
@@index_b.bdy

prompt
prompt Creating package ORA_GOOD_B
prompt ===========================
prompt
@@ora_good_b.spc
@@ora_good_b.bdy

prompt
prompt Creating package BASIC_IO_B
prompt ===========================
prompt
@@basic_io_b.spc
@@basic_io_b.bdy


prompt
prompt Creating package CHARSET_B
prompt ==========================
prompt
@@charset_b.spc
@@charset_b.bdy
prompt
prompt Creating package NEGOTIATION_B
prompt ==============================
prompt
@@negotiation_b.spc
@@negotiation_b.bdy


prompt
prompt Creating package HTML_B
prompt =======================
prompt
@@html_b.spc
@@html_b.bdy
prompt
prompt Creating package HTTP_B
prompt =======================
prompt
@@http_b.spc
@@http_b.bdy

prompt
prompt Creating package ERROR_B
prompt ========================
prompt
@@error_b.spc
@@error_b.bdy
prompt
prompt Creating package LONG_OPS_B
prompt ========================
prompt
@@long_ops_b.prc

prompt
prompt Creating package CACHE_B
prompt ========================
prompt
@@cache_b.spc
prompt
prompt Creating package body CACHE_B
prompt =============================
prompt
@@cache_b.bdy

prompt
prompt Creating package TEST_B
prompt =======================
prompt
@@test_b.spc
@@test_b.bdy
prompt
prompt Creating package TEST_C
prompt =======================
prompt
@@test_c.spc
@@test_c.bdy

-- download/upload, direct reqeust/response entity body ---

prompt
prompt Creating package FILE_DL_B
prompt ==========================
prompt
@@file_dl_b.spc
@@file_dl_b.bdy
prompt
prompt Creating package POST_B
prompt =======================
prompt
@@post_b.spc
@@post_b.bdy
prompt
prompt Creating package POST_FILE_B
prompt ============================
prompt
@@post_file_b.spc
@@post_file_b.bdy
prompt
prompt Creating package UPLOAD_B
prompt =========================
prompt
@@upload_b.spc
@@upload_b.bdy
prompt
prompt Creating package MEDIA_B
prompt =========================
prompt
@@media_b.spc
@@media_b.bdy

--------------------------------------

prompt
prompt Creating package RCPV
prompt =====================
prompt
@@rcpv.spc
prompt
prompt Creating package RC
prompt ===================
prompt
@@rc.spc
@@rc.bdy

prompt
prompt Creating package TERM_B
prompt =======================
prompt
@@term_b.spc
@@term_b.bdy

---------  user auth & session  ------

@@t_user.trg

@@user_b.spc
@@user_c.spc
@@auth_s.spc
@@profile_s.spc
@@auth_b.spc
@@session_b.spc

@@user_b.bdy
@@user_c.bdy
@@auth_s.bdy
@@profile_s.bdy
@@auth_b.bdy
@@session_b.bdy


prompt
prompt Creating package PV
prompt ===================
prompt
@@pv.spc
prompt
prompt Creating package FILTER_B
prompt =========================
prompt
@@filter_b.spc
@@filter_b.bdy
prompt
prompt Creating package K_FILTER
prompt =========================
prompt
@@k_filter.spc
@@k_filter.bdy

---------  print/output/response API demos ------------

prompt
prompt Creating package PG_TEST_B
prompt ==========================
prompt
@@pg_test_b.spc
@@pg_test_b.bdy

prompt
prompt Creating package DB_SRC_B
prompt =========================
prompt
@@db_src_b.spc
@@db_src_b.bdy

prompt
prompt Creating procedure URL_TEST1_B
prompt ==============================
prompt
@@url_test1_b.prc

prompt
prompt Creating procedure URL_TEST2_B
prompt ==============================
prompt
@@url_test2_b.prc

prompt
prompt Creating package EASY_URL_B
prompt ==========================
prompt
@@easy_url_b.spc
@@easy_url_b.bdy

prompt
prompt Creating package STYLE_B
prompt ==========================
prompt
@@style_b.spc
@@style_b.bdy

prompt
prompt Creating package LIST_B
prompt ==========================
prompt
@@list_b.spc
@@list_b.bdy

prompt
prompt Creating package TREE_B
prompt ==========================
prompt
@@tree_b.spc
@@tree_b.bdy

prompt css framework integration demos

prompt
prompt Creating package BOOTSTRAP_B
prompt ==========================
prompt
@@bootstrap_b.spc
@@bootstrap_b.bdy

prompt
prompt Creating package JQM_B
prompt ==========================
prompt
@@jqm_b.spc
@@jqm_b.bdy


prompt
prompt Creating package XML_PAGE_B
prompt ===========================
prompt
@@xml_page_b.spc
@@xml_page_b.bdy

prompt
prompt Creating package JSON_B
prompt ===========================
prompt
@@json_b.spc
@@json_b.bdy

-------------------------------------------

prompt leverage oracle types and subtype
whenever sqlerror continue
@@tool.tps
@@tool.tpb
@@tool2.tps
@@tool2.tpb
whenever sqlerror exit
@@user_type_b.spc
@@user_type_b.bdy

prompt reuse js/css resource in container page, reduce repeated load of same url
@@po_ajaxload_b.spc
@@po_ajaxload_b.bdy
@@po_content_b.spc
@@po_content_b.bdy
@@po_frameset_b.spc
@@po_frameset_b.bdy
@@po_iframe_b.spc
@@po_iframe_b.bdy

prompt adapt to different types of terminals, all screen sizes and resolutions, be responsive
@@layout_b.spc
@@layout_b.bdy
@@scale_b.spc
@@scale_b.bdy

prompt performance tester
@@speed_test_e.spc
@@speed_test_e.bdy
@@array_test_e.spc
@@array_test_e.bdy
@@lob_test_e.spc
@@lob_test_e.bdy
@@css_prof_b.spc
@@css_prof_b.bdy
@@result_cache_b.spc
@@result_cache_b.bdy

@@msg_b.spc
@@msg_b.bdy
@@msg_c.spc
@@msg_c.bdy

set define on
set echo off
