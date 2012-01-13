-----------------------------------------------
-- Export file for user PSP                  --
-- Created by Li Yong on 2012-1-13, 17:23:16 --
-----------------------------------------------

spool q.log

prompt
prompt Creating table CACHE_CFG_T
prompt ==========================
prompt
@@cache_cfg_t.tab
prompt
prompt Creating table CACHE_T
prompt ======================
prompt
@@cache_t.tab
prompt
prompt Creating table CMP_PROG_VERSION
prompt ===============================
prompt
@@cmp_prog_version.tab
prompt
prompt Creating table CONFIG_T
prompt =======================
prompt
@@config_t.tab
prompt
prompt Creating table DAD_T
prompt ====================
prompt
@@dad_t.tab
prompt
prompt Creating table DATA_TRAFFIC_T
prompt =============================
prompt
@@data_traffic_t.tab
prompt
prompt Creating table DEV_LOGIN_T
prompt ==========================
prompt
@@dev_login_t.tab
prompt
prompt Creating table DIR_T
prompt ====================
prompt
@@dir_t.tab
prompt
prompt Creating table EXT_URL_T
prompt ========================
prompt
@@ext_url_t.tab
prompt
prompt Creating table GRAB_CFG_T
prompt =========================
prompt
@@grab_cfg_t.tab
prompt
prompt Creating table PBLD_LAST_PARA
prompt =============================
prompt
@@pbld_last_para.tab
prompt
prompt Creating table PBLD_PAGE_HEADER
prompt ===============================
prompt
@@pbld_page_header.tab
prompt
prompt Creating table PBLD_SCHEMA_CONFIG
prompt =================================
prompt
@@pbld_schema_config.tab
prompt
prompt Creating table PSP_PACK_T
prompt =========================
prompt
@@psp_pack_t.tab
prompt
prompt Creating table PSP_PROC_T
prompt =========================
prompt
@@psp_proc_t.tab
prompt
prompt Creating table RAND_T
prompt =====================
prompt
@@rand_t.tab
prompt
prompt Creating table UPLOAD_FILE_T
prompt ============================
prompt
@@upload_file_t.tab
prompt
prompt Creating sequence S_CACHE_ID
prompt ============================
prompt
@@s_cache_id.seq
prompt
prompt Creating sequence S_FEEDBACK
prompt ============================
prompt
@@s_feedback.seq
prompt
prompt Creating sequence S_UPLOAD_FILE_ID
prompt ==================================
prompt
@@s_upload_file_id.seq
prompt
prompt Creating view EXT_URL_V
prompt =======================
prompt
@@ext_url_v.vw
prompt
prompt Creating view PBLD_PAGE_HEADER_V
prompt ================================
prompt
@@pbld_page_header_v.vw
prompt
prompt Creating view PSP_PACK_V
prompt ========================
prompt
@@psp_pack_v.vw
prompt
prompt Creating view PSP_PROC_V
prompt ========================
prompt
@@psp_proc_v.vw
prompt
prompt Creating package CPV
prompt ====================
prompt
@@cpv.spc
prompt
prompt Creating package DAD_B
prompt ======================
prompt
@@dad_b.spc
prompt
prompt Creating package DEFAULT_B
prompt ==========================
prompt
@@default_b.spc
prompt
prompt Creating type ST
prompt ================
prompt
@@st.tps
prompt
prompt Creating package FB
prompt ===================
prompt
@@fb.spc
prompt
prompt Creating package IMP_C
prompt ======================
prompt
@@imp_c.spc
prompt
prompt Creating package IR_REPEATER
prompt ============================
prompt
@@ir_repeater.spc
prompt
prompt Creating package JS
prompt ===================
prompt
@@js.spc
prompt
prompt Creating package K_ANTI_REDO
prompt ============================
prompt
@@k_anti_redo.spc
prompt
prompt Creating package K_AUTH
prompt =======================
prompt
@@k_auth.spc
prompt
prompt Creating package K_CACHE
prompt ========================
prompt
@@k_cache.spc
prompt
prompt Creating package K_CACHE_CFG
prompt ============================
prompt
@@k_cache_cfg.spc
prompt
prompt Creating package K_CCFLAG
prompt =========================
prompt
@@k_ccflag.spc
prompt
prompt Creating package K_CFG_READER
prompt =============================
prompt
@@k_cfg_reader.spc
prompt
prompt Creating package K_CM
prompt =====================
prompt
@@k_cm.spc
prompt
prompt Creating package K_COOKIE
prompt =========================
prompt
@@k_cookie.spc
prompt
prompt Creating package K_DAD
prompt ======================
prompt
@@k_dad.spc
prompt
prompt Creating package K_DAD_ADM
prompt ==========================
prompt
@@k_dad_adm.spc
prompt
prompt Creating package K_EXCEPTION
prompt ============================
prompt
@@k_exception.spc
prompt
prompt Creating package K_FILE
prompt =======================
prompt
@@k_file.spc
prompt
prompt Creating package K_FILE2
prompt ========================
prompt
@@k_file2.spc
prompt
prompt Creating package K_FILTER
prompt =========================
prompt
@@k_filter.spc
prompt
prompt Creating package K_GAC
prompt ======================
prompt
@@k_gac.spc
prompt
prompt Creating package K_GC
prompt =====================
prompt
@@k_gc.spc
prompt
prompt Creating package K_GEN_CODE
prompt ===========================
prompt
@@k_gen_code.spc
prompt
prompt Creating package K_GW
prompt =====================
prompt
@@k_gw.spc
prompt
prompt Creating package K_HOOK
prompt =======================
prompt
@@k_hook.spc
prompt
prompt Creating package K_HTTP
prompt =======================
prompt
@@k_http.spc
prompt
prompt Creating package K_LOADPSP
prompt ==========================
prompt
@@k_loadpsp.spc
prompt
prompt Creating package K_PROXY
prompt ========================
prompt
@@k_proxy.spc
prompt
prompt Creating package K_RESOLVE
prompt ==========================
prompt
@@k_resolve.spc
prompt
prompt Creating package K_SETTING
prompt ==========================
prompt
@@k_setting.spc
prompt
prompt Creating package K_TRAFFIC
prompt ==========================
prompt
@@k_traffic.spc
prompt
prompt Creating type NT
prompt ================
prompt
@@nt.tps
prompt
prompt Creating package K_TYPE_TOOL
prompt ============================
prompt
@@k_type_tool.spc
prompt
prompt Creating package K_UPGRADER
prompt ===========================
prompt
@@k_upgrader.spc
prompt
prompt Creating package K_URL
prompt ======================
prompt
@@k_url.spc
prompt
prompt Creating package K_XHTP
prompt =======================
prompt
@@k_xhtp.spc
prompt
prompt Creating package PAGE_GEN_SPEED_TEST
prompt ====================================
prompt
@@page_gen_speed_test.spc
prompt
prompt Creating package PC
prompt ===================
prompt
@@pc.spc
prompt
prompt Creating package PROXY_B
prompt ========================
prompt
@@proxy_b.spc
prompt
prompt Creating package PSD_BE_HTML
prompt ============================
prompt
@@psd_be_html.spc
prompt
prompt Creating package PSP_AUTH_DAD_C
prompt ===============================
prompt
@@psp_auth_dad_c.spc
prompt
prompt Creating package PSP_CODE_GEN
prompt =============================
prompt
@@psp_code_gen.spc
prompt
prompt Creating package PSP_CODE_GEN_B
prompt ===============================
prompt
@@psp_code_gen_b.spc
prompt
prompt Creating package PSP_DAD_ADM_B
prompt ==============================
prompt
@@psp_dad_adm_b.spc
prompt
prompt Creating package R
prompt ==================
prompt
@@r.spc
prompt
prompt Creating package PSP_ENTRY_B
prompt ============================
prompt
@@psp_entry_b.spc
prompt
prompt Creating package PSP_PAGE_HEADER_B
prompt ==================================
prompt
@@psp_page_header_b.spc
prompt
prompt Creating package PSP_PAGE_TEST_B
prompt ================================
prompt
@@psp_page_test_b.spc
prompt
prompt Creating package PSP_PROG_B
prompt ===========================
prompt
@@psp_prog_b.spc
prompt
prompt Creating package PSP_PROG_C
prompt ===========================
prompt
@@psp_prog_c.spc
prompt
prompt Creating package TMP
prompt ====================
prompt
@@tmp.spc
prompt
prompt Creating function N
prompt ===================
prompt
@@n.fnc
prompt
prompt Creating function SPLIT4TAB
prompt ===========================
prompt
@@split4tab.fnc
prompt
prompt Creating function U
prompt ===================
prompt
@@u.fnc
prompt
prompt Creating function U1
prompt ====================
prompt
@@u1.fnc
prompt
prompt Creating function U2
prompt ====================
prompt
@@u2.fnc
prompt
prompt Creating procedure DAD_AUTH_ENTRY
prompt =================================
prompt
@@dad_auth_entry.prc
prompt
prompt Creating procedure SERVLET
prompt ==========================
prompt
@@servlet.prc
prompt
prompt Creating package body CPV
prompt =========================
prompt
@@cpv.bdy
prompt
prompt Creating package body DAD_B
prompt ===========================
prompt
@@dad_b.bdy
prompt
prompt Creating package body DEFAULT_B
prompt ===============================
prompt
@@default_b.bdy
prompt
prompt Creating package body FB
prompt ========================
prompt
@@fb.bdy
prompt
prompt Creating package body IMP_C
prompt ===========================
prompt
@@imp_c.bdy
prompt
prompt Creating package body IR_REPEATER
prompt =================================
prompt
@@ir_repeater.bdy
prompt
prompt Creating package body JS
prompt ========================
prompt
@@js.bdy
prompt
prompt Creating package body K_ANTI_REDO
prompt =================================
prompt
@@k_anti_redo.bdy
prompt
prompt Creating package body K_AUTH
prompt ============================
prompt
@@k_auth.bdy
prompt
prompt Creating package body K_CACHE
prompt =============================
prompt
@@k_cache.bdy
prompt
prompt Creating package body K_CACHE_CFG
prompt =================================
prompt
@@k_cache_cfg.bdy
prompt
prompt Creating package body K_CCFLAG
prompt ==============================
prompt
@@k_ccflag.bdy
prompt
prompt Creating package body K_CFG_READER
prompt ==================================
prompt
@@k_cfg_reader.bdy
prompt
prompt Creating package body K_CM
prompt ==========================
prompt
@@k_cm.bdy
prompt
prompt Creating package body K_COOKIE
prompt ==============================
prompt
@@k_cookie.bdy
prompt
prompt Creating package body K_DAD_ADM
prompt ===============================
prompt
@@k_dad_adm.bdy
prompt
prompt Creating package body K_EXCEPTION
prompt =================================
prompt
@@k_exception.bdy
prompt
prompt Creating package body K_FILE
prompt ============================
prompt
@@k_file.bdy
prompt
prompt Creating package body K_FILE2
prompt =============================
prompt
@@k_file2.bdy
prompt
prompt Creating package body K_FILTER
prompt ==============================
prompt
@@k_filter.bdy
prompt
prompt Creating package body K_GAC
prompt ===========================
prompt
@@k_gac.bdy
prompt
prompt Creating package body K_GC
prompt ==========================
prompt
@@k_gc.bdy
prompt
prompt Creating package body K_GEN_CODE
prompt ================================
prompt
@@k_gen_code.bdy
prompt
prompt Creating package body K_GW
prompt ==========================
prompt
@@k_gw.bdy
prompt
prompt Creating package body K_HOOK
prompt ============================
prompt
@@k_hook.bdy
prompt
prompt Creating package body K_HTTP
prompt ============================
prompt
@@k_http.bdy
prompt
prompt Creating package body K_LOADPSP
prompt ===============================
prompt
@@k_loadpsp.bdy
prompt
prompt Creating package body K_PROXY
prompt =============================
prompt
@@k_proxy.bdy
prompt
prompt Creating package body K_RESOLVE
prompt ===============================
prompt
@@k_resolve.bdy
prompt
prompt Creating package body K_SETTING
prompt ===============================
prompt
@@k_setting.bdy
prompt
prompt Creating package body K_TRAFFIC
prompt ===============================
prompt
@@k_traffic.bdy
prompt
prompt Creating package body K_TYPE_TOOL
prompt =================================
prompt
@@k_type_tool.bdy
prompt
prompt Creating package body K_UPGRADER
prompt ================================
prompt
@@k_upgrader.bdy
prompt
prompt Creating package body K_URL
prompt ===========================
prompt
@@k_url.bdy
prompt
prompt Creating package body K_XHTP
prompt ============================
prompt
@@k_xhtp.bdy
prompt
prompt Creating package body PAGE_GEN_SPEED_TEST
prompt =========================================
prompt
@@page_gen_speed_test.bdy
prompt
prompt Creating package body PC
prompt ========================
prompt
@@pc.bdy
prompt
prompt Creating package body PROXY_B
prompt =============================
prompt
@@proxy_b.bdy
prompt
prompt Creating package body PSD_BE_HTML
prompt =================================
prompt
@@psd_be_html.bdy
prompt
prompt Creating package body PSP_AUTH_DAD_C
prompt ====================================
prompt
@@psp_auth_dad_c.bdy
prompt
prompt Creating package body PSP_CODE_GEN_B
prompt ====================================
prompt
@@psp_code_gen_b.bdy
prompt
prompt Creating package body PSP_DAD_ADM_B
prompt ===================================
prompt
@@psp_dad_adm_b.bdy
prompt
prompt Creating package body PSP_ENTRY_B
prompt =================================
prompt
@@psp_entry_b.bdy
prompt
prompt Creating package body PSP_PAGE_HEADER_B
prompt =======================================
prompt
@@psp_page_header_b.bdy
prompt
prompt Creating package body PSP_PAGE_TEST_B
prompt =====================================
prompt
@@psp_page_test_b.bdy
prompt
prompt Creating package body PSP_PROG_B
prompt ================================
prompt
@@psp_prog_b.bdy
prompt
prompt Creating package body PSP_PROG_C
prompt ================================
prompt
@@psp_prog_c.bdy
prompt
prompt Creating package body R
prompt =======================
prompt
@@r.bdy
prompt
prompt Creating trigger T_SRC_LOG
prompt ==========================
prompt
@@t_src_log.trg
prompt
prompt Creating trigger T_UPLOAD_FILE
prompt ==============================
prompt
@@t_upload_file.trg

spool off
