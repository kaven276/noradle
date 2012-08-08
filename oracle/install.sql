prompt Are you sure that you are in the psp.web project's oracle subdir,
pause if not, break(CTRL-C) and cd it and retry ...
whenever sqlerror exit

accept pspdbu char default 'psp' prompt 'Enter the schema/User(must already exist) for psp.web software (psp) : '
accept demodbu char default 'demo' prompt 'Enter the schema/User(must already exist) for psp.web demo (demo) : '

prompt Installing objects in sys,
pause press any key to continue ...
remark install on sys
@@pw.pck

prompt Installing psp.web engine software, 
pause press any key to continue ...
alter session set current_schema = &pspdbu;
@@grant2psp.sql

set scan off
whenever sqlerror continue
drop sequence GAC_CID_SEQ;
drop table SERVER_CONTROL_T cascade constraints
drop table EXT_URL_T cascade constraints
whenever sqlerror exit
@psp/install_psp_obj.sql
set scan on
exec DBMS_UTILITY.COMPILE_SCHEMA('&pspdbu',false);
insert into SERVER_CONTROL_T (GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME, STATIC_URL)
values ('127.0.0.1', 1522, 6, 12, 1000, '+0001 00:00:30', 'http://127.0.0.1:81');
commit;
@@contexts.sql
@@grant_api.sql
@@pub_synonym.sql

prompt Installing psp.web demo app, 
pause press any key to continue ...
alter session set current_schema = &demodbu;
@@grant2demo.sql
set scan off
@demo/install_demo_obj.sql
create or replace context A#DEMO using auth_s accessed globally;
grant execute on A#DEMO to &pspdbu;
set scan on
exec DBMS_UTILITY.COMPILE_SCHEMA('&demodbu',false);