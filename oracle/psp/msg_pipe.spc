create or replace package msg_pipe is

	procedure pipe2node;
	procedure node2pipe;

	function pipe2param
	(
		pipe    varchar2,
		timeout number
	) return boolean;

	procedure begin_msg;
	procedure set_header
	(
		name  varchar2,
		value varchar2
	);
	procedure send_msg(pipe varchar2);
	procedure fetch_msg;

end msg_pipe;
/
