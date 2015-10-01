create or replace package bios is

	-- Author  : ADMINISTRATOR
	-- Created : 2015-5-11 11:28:55
	-- Purpose : read request, write response
	
	procedure init_req_pv;

	procedure read_request;

	procedure wpi(i binary_integer);

	procedure write_frame(ftype pls_integer);

	procedure write_frame
	(
		ftype pls_integer,
		v     in out nocopy varchar2
	);

	procedure write_head;

	procedure write_session;

	procedure write_end;

end bios;
/
