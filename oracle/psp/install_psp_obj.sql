----------------------------------------------
-- Export file for user NEWPSPTEST          --
-- Created by Li Yong on 2012-3-19, 9:22:37 --
----------------------------------------------

spool install_psp_obj.log

prompt
prompt Creating table EXT_URL_T
prompt ========================
prompt
@@ext_url_t.tab
prompt
prompt Creating table SERVER_CONTROL_T
prompt ===============================
prompt
@@server_control_t.tab
prompt
prompt Creating sequence GAC_CID_SEQ
prompt =============================
prompt
@@gac_cid_seq.seq
prompt
prompt Creating view EXT_URL_V
prompt =======================
prompt
@@ext_url_v.vw
prompt
prompt Creating package E
prompt ==================
prompt
@@e.spc
prompt
prompt Creating package G
prompt ==================
prompt
@@g.spc
prompt
prompt Creating package GATEWAY
prompt ========================
prompt
@@gateway.spc
prompt
prompt Creating package KV
prompt ===================
prompt
@@kv.spc
prompt
prompt Creating package K_BROKER
prompt =========================
prompt
@@k_broker.spc
prompt
prompt Creating package K_CCFLAG
prompt =========================
prompt
@@k_ccflag.spc
prompt
prompt Creating package K_CFG
prompt ======================
prompt
@@k_cfg.spc
prompt
prompt Creating type ST
prompt ================
prompt
@@st.tps
prompt
prompt Creating package K_DEBUG
prompt ========================
prompt
@@k_debug.spc
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
prompt Creating package K_GW
prompt =====================
prompt
@@k_gw.spc
prompt
prompt Creating package K_HTTP
prompt =======================
prompt
@@k_http.spc
prompt
prompt Creating package K_PMON
prompt =======================
prompt
@@k_pmon.spc
prompt
prompt Creating package K_SESS
prompt =======================
prompt
@@k_sess.spc
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
prompt Creating package OUTPUT
prompt =======================
prompt
@@output.spc
prompt
prompt Creating package PV
prompt ===================
prompt
@@pv.spc
prompt
prompt Creating package R
prompt ==================
prompt
@@r.spc
prompt
prompt Creating package RA
prompt ===================
prompt
@@ra.spc
prompt
prompt Creating package RB
prompt ===================
prompt
@@rb.spc
prompt
prompt Creating package RS
prompt ===================
prompt
@@rs.spc
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
prompt Creating function U
prompt ===================
prompt
@@u.fnc
prompt
prompt Creating package body E
prompt =======================
prompt
@@e.bdy
prompt
prompt Creating package body G
prompt =======================
prompt
@@g.bdy
prompt
prompt Creating package body GATEWAY
prompt =============================
prompt
@@gateway.bdy
prompt
prompt Creating package body KV
prompt ========================
prompt
@@kv.bdy
prompt
prompt Creating package body K_BROKER
prompt ==============================
prompt
@@k_broker.bdy
prompt
prompt Creating package body K_CCFLAG
prompt ==============================
prompt
@@k_ccflag.bdy
prompt
prompt Creating package body K_CFG
prompt ===========================
prompt
@@k_cfg.bdy
prompt
prompt Creating package body K_DEBUG
prompt =============================
prompt
@@k_debug.bdy
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
prompt Creating package body K_GW
prompt ==========================
prompt
@@k_gw.bdy
prompt
prompt Creating package body K_HTTP
prompt ============================
prompt
@@k_http.bdy
prompt
prompt Creating package body K_PMON
prompt ============================
prompt
@@k_pmon.bdy
prompt
prompt Creating package body K_SESS
prompt ============================
prompt
@@k_sess.bdy
prompt
prompt Creating package body K_TYPE_TOOL
prompt =================================
prompt
@@k_type_tool.bdy
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
prompt Creating package body OUTPUT
prompt ============================
prompt
@@output.bdy
prompt
prompt Creating package body R
prompt =======================
prompt
@@r.bdy
prompt
prompt Creating package body RS
prompt =======================
prompt
@@rs.bdy

spool off
