create or replace package callout_broker_h is

	procedure emit_messages;

	procedure user_change_manual_stream;

	procedure user_change_handler;

	procedure sms;

end callout_broker_h;
/
