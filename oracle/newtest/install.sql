-----------------------------------------------
-- Export file for user NEWPSPTEST           --
-- Created by Li Yong on 2012-1-13, 21:07:30 --
-----------------------------------------------

spool install.log

prompt
prompt Creating package GATEWAY
prompt ========================
prompt
@@gateway.spc
prompt
prompt Creating package P
prompt ==================
prompt
@@p.spc
prompt
prompt Creating package R
prompt ==================
prompt
@@r.spc
prompt
prompt Creating package TEST_B
prompt =======================
prompt
@@test_b.spc
prompt
prompt Creating package body GATEWAY
prompt =============================
prompt
@@gateway.bdy
prompt
prompt Creating package body P
prompt =======================
prompt
@@p.bdy
prompt
prompt Creating package body R
prompt =======================
prompt
@@r.bdy
prompt
prompt Creating package body TEST_B
prompt ============================
prompt
@@test_b.bdy

spool off
