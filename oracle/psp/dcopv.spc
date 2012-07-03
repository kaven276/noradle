create or replace package dcopv is

	con   utl_tcp.connection;
	msg   blob;
	pos   pls_integer;
	chksz pls_integer;

end dcopv;
/
