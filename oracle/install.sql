set echo off
spool install.log replace
pause install log will write to "install.log", please check it after the script run

prompt Are you sure that you are in the Noradle(psp.web) project's oracle subdir,
pause if not, break(CTRL-C) and cd it and retry ...
whenever sqlerror exit

set define on

prompt Installing objects in sys,
pause press enter to continue ...
remark install on sys
prompt Warning: PLSHPROF_DIR is set to '', if use oracle's hprof, set it to valid path first.
CREATE or replace DIRECTORY PLSHPROF_DIR AS '';
@@pw.pck

prompt xmldb must be installed already
prompt see and run $ORACLE_HOME/rdbms/admin/catqm.sql
Rem    NAME
Rem      catqm.sql - CAtalog script for sQl xMl management
Rem
Rem    DESCRIPTION
Rem      Creates the tables and views needed to run the XDB system
Rem      Run this script like this:
Rem        catqm.sql <XDB_PASSWD> <TABLESPACE> <TEMP_TABLESPACE> <SECURE_FILES_REPO>
Rem          -- XDB_PASSWD: password for XDB user
Rem          -- TABLESPACE: tablespace for XDB
Rem          -- TEMP_TABLESPACE: temporary tablespace for XDB
Rem          -- SECURE_FILES_REPO: if YES and compatibility is at least 11.2,
Rem               then XDB repository will be stored as secure files;
Rem               otherwise, old LOBS are used. There is no default value for
Rem               this parameter, the caller must pass either YES or NO.
@@grant_network.sql

--------------------------------------------------------------------------------

prompt Are you sure you have clean empty PSP db user/schema already?
prompt Noradle's core units(tables,plsql,...) in oracle will be installed to the schema
prompt You can try the sql scripts below to achieve the preparation required above.
prompt exec psp.k_pmon.stop
prompt drop user psp cascade;;
prompt create user psp identified by psp default tablespace users;;
pause if not, create empty PSP db user beforehand, and then press enter to continue
accept pspdbu char default 'psp' prompt 'Enter the schema/User(must already exist) for noradle software (psp) : '

prompt Installing Noradle(psp.web) engine software to schema "&pspdbu",
pause press enter to continue ...
alter session set current_schema = &pspdbu;
@@grant2psp.sql

whenever sqlerror continue
prompt Notice: all the drop objects errors can be ignored, do not care about it
create table SERVER_CONTROL_BAK as select * from SERVER_CONTROL_T;
create table EXT_URL_BAK as select * from EXT_URL_T;
drop sequence GAC_CID_SEQ;
drop table SERVER_CONTROL_T cascade constraints;
drop table EXT_URL_T cascade constraints;
drop table DBMSHP_RUNS cascade constraints;
drop table DBMSHP_FUNCTION_INFO cascade constraints;
drop table DBMSHP_PARENT_CHILD_INFO cascade constraints;
drop sequence DBMSHP_RUNNUMBER;
whenever sqlerror exit

remark start $ORACLE_HOME/rdbms/admin/dbmshptab.sql
prompt begin to install Noradle system schema objects
@psp/install_psp_obj.sql
exec DBMS_UTILITY.COMPILE_SCHEMA(upper('&pspdbu'),false);

whenever sqlerror continue
prompt Notice: restore old config data
insert into SERVER_CONTROL_T select * from SERVER_CONTROL_BAK;
insert into EXT_URL_T select * from EXT_URL_BAK;
drop table SERVER_CONTROL_BAK cascade constraints;
drop table EXT_URL_BAK cascade constraints;
desc SERVER_CONTROL_T
insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME,IDLE_TIMEOUT)
values ('demo', '127.0.0.1', 1522, 4, 12, 1000, '+0001 00:00:00', 300);
commit;
whenever sqlerror exit

@@contexts.sql
@@grant_api.sql
@@pub_synonym.sql

--------------------------------------------------------------------------------

prompt Are you sure you have clean empty DEMO db user/schema already?
prompt Noradle demo's units(tables,plsql,...) in oracle will be installed to the schema
prompt You can try the sql scripts below to achieve the preparation required above.
prompt drop user demo cascade;;
prompt create user demo identified by demo default tablespace users;;
pause if not, create empty DEMO db users beforehand, and then press enter to continue
accept demodbu char default 'demo' prompt 'Enter the schema/User(must already exist) for noradle demo (demo) : '

whenever sqlerror continue
prompt Installing Noracle(psp.web) demo app to schema "&demodbu"
pause press enter to continue ...
alter session set current_schema = &demodbu;
@@grant2demo.sql

prompt begin to install Noradle demo schema objects
@../demo/schema/install_demo_obj.sql

whenever sqlerror continue
exec DBMS_UTILITY.COMPILE_SCHEMA(upper('&demodbu'),false);
insert into ext_url_v(key,prefix) values('myself','/f');
commit;

prompt Noradle bundle in oracle db part have been installed successfully!
prompt Please follow the steps below to learn from demo
prompt 1. config server_config_t, let oracle known where to reverse connect nodejs
prompt 2. run nodejs server, quick start with default cfg by "cd demo", "npm start"
prompt 3. in oracle psp schema, exec "k_pmon.run_job" to start processes to serv.
prompt 4. in your browser, access "http://localhost:8888/demo" (for example) to see the demo
spool off