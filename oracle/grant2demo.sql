-- Grant/Revoke object privileges 
grant execute on SYS.DBMS_CRYPTO to &demodbu;
grant execute on SYS.DBMS_LOCK to &demodbu;
grant execute on SYS.DBMS_OBFUSCATION_TOOLKIT to &demodbu;
grant execute on SYS.DBMS_OBFUSCATION_TOOLKIT_FFI to &demodbu;
grant execute on SYS.DBMS_PIPE to &demodbu;
grant execute on SYS.DBMS_HPROF to &demodbu;

-- Grant/Revoke role privileges 
grant resource to &demodbu;

-- Grant/Revoke system privileges 
grant create session to &demodbu;
