create or replace package dcopv is

	type rsp_t is table of blob index by binary_integer;
	rsps rsp_t;

	nl constant raw(1) := hextoraw('0A');

	con      utl_tcp.connection;
	msg      blob;
	zblb     blob; -- zero blob for placeholder
	pos_tail pls_integer; -- tail of current message in buffer
	pos_head pls_integer; -- head of current message in buffer
	chksz    pls_integer := 8132;
	rseq     pls_integer := 0; -- current/recent request sequence
	onway    pls_integer; -- pending reply count on wire
	onbuf    pls_integer; -- pending reply count on buffer

	host varchar2(99); -- current connected server host
	port number(5); -- current connected server port

	crseq pls_integer;
	crpos pls_integer;

	rtcp   pls_integer;
	tmp_pi pls_integer;
	tmp_s  varchar2(30);
	tmp_n  number;
	tmp_b  boolean;

	ex_tcp_security exception;
	pragma exception_init(ex_tcp_security, -53203);

end dcopv;
/
