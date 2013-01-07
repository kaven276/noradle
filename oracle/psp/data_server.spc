create or replace package data_server is

	procedure serv;

	procedure onex
	(
		code number,
		errm varchar2
	);

end data_server;
/
