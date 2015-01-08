create or replace package msg_pipe authid current_user is

	procedure pipe2node;
	procedure node2pipe;

	function pipe2param
	(
		pipe    varchar2 := null,
		timeout number := null
	) return boolean;

	procedure begin_msg(nlbr varchar2 := null);
	procedure set_callback_pipename(pipename varchar2 := null);
	procedure send_msg(pipe varchar2 := null);
	procedure fetch_msg;

end msg_pipe;
/
