create or replace package gateway is

	ex_resp_done exception;
	ex_fltr_done exception;

	pragma exception_init(ex_resp_done, -20998);
	pragma exception_init(ex_fltr_done, -20999);

	procedure listen;

end gateway;
/
