create or replace package body k_ccflag is

  function  get_ext_fs return varchar2 is
    begin
      --return 'http://61.181.22.71:1234';
			-- return 'http://192.168.177.1:8888';
      return '';
      --return 'http://192.168.0.101';
      return 'http://localhost:8888';
      -- return 'file:///Users/cuccpkfs/dev/static';
      return 'http://60.29.143.50:8888';
    end;
  
end k_ccflag;
/

