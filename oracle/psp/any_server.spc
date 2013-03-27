create or replace package any_server is

	procedure serv;

	procedure onex
	(
		code number,
		errm varchar2
	);

end any_server;
/
