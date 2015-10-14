-----------------------------------------------------
-- Export file for user PSP                        --
-- Created by Administrator on 2013-4-18, 11:18:01 --
-----------------------------------------------------

set define off
set echo on

whenever sqlerror continue
prompt Notice: all the drop objects errors can be ignored, do not care about it
create table SERVER_CONTROL_BAK as select * from SERVER_CONTROL_T;
create table CLIENT_CONTROL_BAK as select * from CLIENT_CONTROL_T;
create table EXT_URL_BAK as select * from EXT_URL_T;
drop table SERVER_CONTROL_T cascade constraints;
drop table CLIENT_CONTROL_T cascade constraints;
drop table EXT_URL_T cascade constraints;
whenever sqlerror exit

--------------------------------------------------------------------------------

prompt
prompt Creating table SERVER_CONTROL_T
prompt ===============================
prompt
@@server_control_t.tab
prompt
prompt Creating table CLIENT_CONTROL_T
prompt ===============================
prompt
@@client_control_t.tab
prompt
prompt Creating table EXT_URL_T
prompt ========================
prompt
@@ext_url_t.tab
prompt
prompt Creating view EXT_URL_V
prompt =======================
prompt
@@ext_url_v.vw

--------------------------------------------------------------------------------

prompt
prompt Creating type ST
prompt ================
prompt
@@st.tps
prompt
prompt Creating type NT
prompt ================
prompt
@@nt.tps
prompt
prompt Creating package TMP
prompt ====================
prompt
@@tmp.spc

--------------------------------------------------------------------------------

prompt
prompt Creating package K_CCFLAG
prompt =========================
prompt
@@k_ccflag.spc
prompt
prompt Creating package PV
prompt ===================
prompt
@@pv.spc
prompt
prompt Creating package STS
prompt ========================
prompt
@@sts.spc

--------------------------------------------------------------------------------

prompt
prompt Creating package G
prompt ==================
prompt
@@g.spc
@@g.bdy

--------------------------------------------------------------------------------

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
prompt Creating package RC
prompt ===================
prompt
@@rc.spc
prompt
prompt Creating package R
prompt ==================
prompt
@@r.spc
@@r.bdy

--------------------------------------------------------------------------------

prompt
prompt Creating package K_TYPE_TOOL
prompt ============================
rem rely on r.client_addr in .gen_token
prompt
@@k_type_tool.spc
@@k_type_tool.bdy
prompt Creating package E
prompt ==================
prompt
@@e.spc
@@e.bdy
prompt
prompt Creating package K_DEBUG
prompt ========================
prompt
@@k_debug.spc
@@k_debug.bdy

prompt Creating package BIOS
prompt =======================
prompt
@@bios.spc
@@bios.bdy
prompt Creating package OUTPUT
prompt =======================
prompt
@@output.spc
@@output.bdy
prompt Creating function url
prompt ========================
prompt
@@url.fnc
prompt
prompt Creating package K_HTTP
prompt =======================
prompt
@@k_http.spc
@@k_http.bdy

--------------------------------------------------------------------------------


prompt
prompt Creating package K_FILTER
prompt =======================
prompt
@@k_filter.spc
@@k_filter.bdy
prompt
prompt Creating package K_GW
prompt =====================
prompt
@@k_gw.spc
@@k_gw.bdy
prompt
prompt Creating procedure DAD_AUTH_ENTRY
prompt =================================
prompt
@@dad_auth_entry.prc
prompt
prompt Creating package K_INIT
prompt =======================
prompt
@@k_init.spc
@@k_init.bdy
prompt
prompt Creating package HTTP_SERVER
prompt ============================
prompt
@@http_server.spc
@@http_server.bdy
prompt
prompt Creating package DATA_SERVER
prompt ============================
prompt
@@data_server.spc
@@data_server.bdy
prompt
prompt Creating package ANY_SERVER
prompt ===========================
prompt
@@any_server.spc
@@any_server.bdy
@@k_cfg.spc
@@k_cfg.bdy
prompt Creating package K_MAPPING
prompt ========================
prompt
@@k_mapping.spc
@@k_mapping.bdy
prompt
prompt Creating package K_CFG
prompt ======================
prompt
prompt Creating package FRAMEWORK
prompt ========================
prompt
@@framework.spc
@@framework.bdy
prompt
prompt Creating procedure kill
prompt ========================
prompt
@@kill.prc
prompt
prompt Creating package K_PMON
prompt =======================
prompt
@@k_pmon.spc
@@k_pmon.bdy

--------------------------------------------------------------------------------

prompt Creating package TAG
prompt ========================
prompt
@@tag.spc
@@tag.bdy

prompt Creating package multi
prompt ========================
prompt
@@multi.spc
@@multi.bdy

prompt Creating package STYLE
prompt ========================
prompt
@@style.spc
@@style.bdy

prompt Creating package list
prompt ========================
prompt
@@list.spc
@@list.bdy

prompt Creating package tree
prompt ========================
prompt
@@tree.spc
@@tree.bdy

prompt
prompt Creating package RS
prompt ===================
prompt
@@rs.spc
@@rs.bdy

prompt Creating package MSG_PIPE
prompt ========================
prompt
@@msg_pipe.spc
@@msg_pipe.bdy

--------------------------------------------------------------------------------

prompt
prompt Creating package KV
prompt ===================
prompt
@@kv.spc
@@kv.bdy
prompt
prompt Creating package CACHE
prompt ======================
prompt
@@cache.spc
@@cache.bdy
prompt
prompt Creating package K_AUTH
prompt =======================
prompt
@@k_auth.spc
@@k_auth.bdy

--------------------------------------------------------------------------------

whenever sqlerror continue
prompt Notice: restore old config data
insert into SERVER_CONTROL_T select * from SERVER_CONTROL_BAK;
insert into CLIENT_CONTROL_T select * from CLIENT_CONTROL_BAK;
insert into EXT_URL_T select * from EXT_URL_BAK;
drop table SERVER_CONTROL_BAK cascade constraints;
drop table CLIENT_CONTROL_BAK cascade constraints;
drop table EXT_URL_BAK cascade constraints;
desc SERVER_CONTROL_T
insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME,IDLE_TIMEOUT)
values ('dispatcher', '127.0.0.1', 1522, 4, 12, 1000, '+0001 00:00:00', 300);
commit;
whenever sqlerror exit

set echo off
set define on
