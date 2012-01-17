create or replace package gateway is

	gc_buff_size pls_integer := 2048; -- 32767

	procedure listen;

end gateway;
/
