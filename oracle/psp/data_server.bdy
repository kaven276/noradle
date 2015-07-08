create or replace package body data_server is

	procedure serv is
	begin
		http_server.serv;
	end;

end data_server;
/
