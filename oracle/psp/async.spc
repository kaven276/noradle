create or replace package async authid current_user is

	procedure listen
	(
		p_pipe_name varchar2,
		p_slot      number
	);

	procedure adjust;

	procedure monitor;

	procedure stop(p_pipe_name varchar2);

	procedure stop_all;

end async;
/
