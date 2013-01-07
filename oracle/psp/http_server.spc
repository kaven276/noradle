create or replace package http_server is

	procedure serv;

	procedure onex
	(
		code number,
		errm varchar2
	);

end http_server;
/
