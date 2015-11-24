set echo off
spool install.log replace
prompt install log will write to "install.log", please check it after the script run
pause press enter to continue

prompt Are you sure that you are in the Noradle(psp.web) project's oracle subdir,
prompt cd `npm -g root`/noradle/oracle
pause if not, break(CTRL-C) and cd it and retry ...
whenever sqlerror exit

set define on

prompt Installing objects in sys,
pause press enter to continue ...
remark install on sys
@@pw.pck

remark start $ORACLE_HOME/rdbms/admin/dbmshptab.sql
remark create directory in SYS, grant read to psp
remark grant read, write on directory SYS.PLSHPROF_DIR to psp;
prompt Warning: PLSHPROF_DIR is set to '', if use oracle's hprof, set it to valid path afterward.
whenever sqlerror continue
CREATE DIRECTORY PLSHPROF_DIR AS '';
whenever sqlerror exit

prompt xmldb must be installed already
prompt if not, see and run $ORACLE_HOME/rdbms/admin/catqm.sql
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
Rem @@grant_network.sql

--------------------------------------------------------------------------------

prompt
prompt Are you sure you have clean empty PSP db user/schema already?
prompt Noradle's core units(tables,plsql,...) in oracle will be installed to the schema
prompt You can try the sql scripts below to achieve the preparation required above.
prompt exec psp.k_pmon.stop;;
prompt drop user psp cascade;;
prompt create user psp identified by psp default tablespace sysaux temporary tablespace temp;;
pause if not, create empty PSP db user beforehand, and then press enter to continue
accept pspdbu char default 'psp' prompt 'Enter the schema/User(must already exist) for noradle software (psp) : '

prompt Installing Noradle(psp.web) engine software to schema "&pspdbu",
pause press enter to continue ...
alter session set current_schema = &pspdbu;
prompt begin to install Noradle system schema objects
@@grant2psp.sql
whenever sqlerror continue
exec k_pmon.stop
rem @?/rdbms/admin/dbmshptab.sql
@@dbmshptab.sql
whenever sqlerror exit
@@psp/install_psp_obj.sql
exec DBMS_UTILITY.COMPILE_SCHEMA(upper('&pspdbu'),false);
@@contexts.sql
@@grant_api.sql
@@pub_synonym.sql

--------------------------------------------------------------------------------

prompt Noradle bundle in oracle db part have been installed successfully!

prompt grant network access, for oracle to reach to dispatcher
@@grant_network.sql

prompt Please follow the steps below to learn from demo
prompt 0. grant network access to the address of dispatcher, for psp user (optional, did by default in this script)
prompt 1. config server_config_t, let oracle known where to reverse connect to dispatcher
prompt 2. start dispatcher
prompt 3. in oracle psp schema, exec k_pmon.run_job to start oracle server processes
prompt 4. install and run noradle-demo app to check if server is running properly
spool off
exit
