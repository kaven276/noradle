set echo off
spool install.log replace
pause install log will write to "install.log", please check it after the script run

prompt Are you sure that you are in the Noradle(psp.web) project's oracle subdir,
pause if not, break(CTRL-C) and cd it and retry ...
whenever sqlerror exit

prompt Are you sure you have clean empty PSP/DEMO db user/schema already?
prompt Noradle's units(tables,plsql,...) in oracle will be installed to the schemas
prompt You can try the sql scripts below to achive the preparation required above.
prompt exec psp.k_pmon.stop
prompt drop user psp cascade;;
prompt drop user demo cascade;;
prompt create user psp identified by psp default tablespace users;;
prompt create user demo identified by demo default tablespace users;;
pause if not, break(CTRL-C) and create empty PSP/DEMO db users beforehand

accept pspdbu char default 'psp' prompt 'Enter the schema/User(must already exist) for psp.web software (psp) : '
accept demodbu char default 'demo' prompt 'Enter the schema/User(must already exist) for psp.web demo (demo) : '

set define on

prompt Installing objects in sys,
pause press any key to continue ...
remark install on sys
prompt Warning: PLSHPROF_DIR is set to '', if use oracle's hprof, set it to valid path first.
CREATE or replace DIRECTORY PLSHPROF_DIR AS '';
@@pw.pck
@@grant_network.sql

prompt Installing Noradle(psp.web) engine software to schema "&pspdbu", 
pause press any key to continue ...
alter session set current_schema = &pspdbu;
@@grant2psp.sql

whenever sqlerror continue
prompt Notice: all the drop objects errors can be ignored, do not care about it
drop sequence GAC_CID_SEQ;
drop table SERVER_CONTROL_T cascade constraints;
drop table EXT_URL_T cascade constraints;
drop table EXTHUB_CONFIG_T cascade constraints;
drop table ASYNC_CONTROL_T cascade constraints;
whenever sqlerror exit

set define off
set echo off
remark start $ORACLE_HOME/rdbms/admin/dbmshptab.sql
prompt begin to install Noradle system schema objects
@psp/install_psp_obj.sql
set define on
set echo on
exec DBMS_UTILITY.COMPILE_SCHEMA('&pspdbu',false);

desc SERVER_CONTROL_T

insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME,
STATIC_URL, DBU_FILTER)
values ('runPSP4WEB', '127.0.0.1', 1522, 0, 12, 1000, '+0001 00:00:00', 'http://127.0.0.1:8000','(demo)');

insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME,
STATIC_URL, DBU_FILTER)
values ('runCombined', '127.0.0.1', 1522, 6, 12, 1000, '+0001 00:00:00', '/fs','(demo)');

insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME, DBU_FILTER)
values ('db-driver', '127.0.0.1', 1523, 2, 6, 1000, '+0001 00:00:00','(demo)');

commit;
@@contexts.sql
@@grant_api.sql
@@pub_synonym.sql

set echo off
prompt Installing Noracle(psp.web) demo app to schema "&demodbu"
pause press any key to continue ...
alter session set current_schema = &demodbu;
@@grant2demo.sql

set define off
set echo off
prompt begin to install Noradle demo schema objects
@demo/install_demo_obj.sql
set define on
set echo on

create or replace context A#DEMO using auth_s accessed globally;
grant execute on auth_s to &pspdbu;
create or replace context demo_profile using profile_s accessed globally;
grant execute on profile_s to &pspdbu;
exec DBMS_UTILITY.COMPILE_SCHEMA('&demodbu',false);
insert into ext_url_v(key,prefix) values('myself','//static-test.noradle.com');
commit;

set echo off
prompt Noradle bundle in oracle db part have been installed successfully!
prompt Please follow the steps below to learn from demo
prompt 1. config server_config_t, let oracle known where to reverse connect nodejs
prompt 2. run nodejs server, quick start with default cfg by "npm start" or "npm start -g noradle"
prompt 3. in oracle psp schema, exec "k_pmon.run_job" to start processes to serv.
prompt 4. in your browser, access "http://localhost:8080/demo" (for example) to see the demo
spool off