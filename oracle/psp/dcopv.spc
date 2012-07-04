create or replace package dcopv is

	type rsp_t is table of blob index by binary_integer;
	rsps rsp_t;

	nl constant raw(1) := hextoraw('0A');

	con   utl_tcp.connection;
	msg   blob;
	zblb  blob; -- zero blob for placeholder
	pos   pls_integer;
	chksz pls_integer := 8132;
	rseq  pls_integer := 0; -- current/recent request sequence

	crseq pls_integer;
	crpos pls_integer;

	rtcp   pls_integer;
	tmp_pi pls_integer;

end dcopv;
/
