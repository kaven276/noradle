create or replace package mv2bg is

	-- message stream related ( using pipe to transfer event key info )
	type event is record(
		pipe_name   varchar2(30),
		req_handler varchar2(99),
		res_handler varchar2(99),
		evt_table   varchar2(30),
		evt_rowid   rowid,
		evt_type    varchar2(30));
	type events is table of event;

	procedure add_event(v event);
	procedure after_commit;
	procedure after_rollback;
	procedure write_event
	(
		broker varchar2,
		v      event
	);
	function read_event(stream_name varchar2 := null) return event;
	procedure stop(broker varchar2);

	procedure auto_stream(stream_name varchar2 := r.getc('stream_name'));

end mv2bg;
/
