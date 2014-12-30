create or replace package msg_pipe is

	procedure pipe2node;
	procedure node2pipe;

	function pipe2param
	(
		pipe    varchar2,
		timeout number
	) return boolean;

end msg_pipe;
/
