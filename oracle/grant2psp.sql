grant execute on SYS.PW to &pspdbu;

-- Grant/Revoke object privileges 
grant execute on SYS.DBMS_ALERT to &pspdbu;
grant execute on SYS.DBMS_CRYPTO to &pspdbu;
grant execute on SYS.DBMS_LOCK to &pspdbu;
grant execute on SYS.DBMS_OBFUSCATION_TOOLKIT_FFI to &pspdbu;
grant execute on SYS.DBMS_PIPE to &pspdbu;
grant execute on SYS.DBMS_SCHEDULER to &pspdbu;
grant execute on SYS.UTL_TCP to &pspdbu;

-- Grant/Revoke role privileges 
grant connect to &pspdbu;
grant resource to &pspdbu;

-- Grant/Revoke system privileges 
grant create any context to &pspdbu;
grant create job to &pspdbu;
grant create session to &pspdbu;
grant create view to &pspdbu;
grant select any dictionary to &pspdbu;
grant select any table to &pspdbu;
