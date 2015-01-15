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
@@pw.pck

remark start $ORACLE_HOME/rdbms/admin/dbmshptab.sql
remark create directory in SYS, grant read to psp
prompt Warning: PLSHPROF_DIR is set to '', if use oracle's hprof, set it to valid path afterward.
whenever sqlerror continue
CREATE DIRECTORY PLSHPROF_DIR AS '';
whenever sqlerror exit

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
prompt begin to install Noradle system schema objects
@@grant2psp.sql
rem @?/rdbms/admin/dbmshptab.sql
@@dbmshptab.sql
@@psp/install_psp_obj.sql
exec DBMS_UTILITY.COMPILE_SCHEMA(upper('&pspdbu'),false);
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

prompt Installing Noracle(psp.web) demo app to schema "&demodbu"
pause press enter to continue ...
alter session set current_schema = &demodbu;
@@grant2demo.sql

prompt begin to install Noradle demo schema objects
@@../demo/schema/install_demo_obj.sql
exec DBMS_UTILITY.COMPILE_SCHEMA(upper('&demodbu'),false);

whenever sqlerror continue
insert into ext_url_v(key,prefix) values('myself','/f');
commit;
whenever sqlerror exit

prompt Noradle bundle in oracle db part have been installed successfully!
prompt Please follow the steps below to learn from demo
prompt 1. config server_config_t, let oracle known where to reverse connect nodejs
prompt 2. run nodejs server, quick start with default cfg by "cd demo", "npm start"
prompt 3. in oracle psp schema, exec "k_pmon.run_job" to start processes to serv.
prompt 4. in your browser, access "http://localhost:8888/demo" (for example) to see the demo
spool off