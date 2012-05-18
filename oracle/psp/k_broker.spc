create or replace package k_broker is

	procedure stream_open;

	procedure stream_close;

	procedure emit_msg;

end k_broker;
/
