create or replace package body data_server is

	procedure serv is
	begin
		http_server.serv;
	end;

	procedure onex
	(
		code number,
		errm varchar2
	) is
	begin
		http_server.onex(code, errm);
	end;

end data_server;
/
