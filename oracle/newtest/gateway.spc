create or replace package gateway is

	gc_buff_size pls_integer := 150;

	procedure listen;

end gateway;
/

