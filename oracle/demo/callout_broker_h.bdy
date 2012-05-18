create or replace package body callout_broker_h is

	procedure emit_messages is
	begin
		bkr.stream_open;
		for i in 1 .. 9 loop
			dbms_lock.sleep(1);
			h.line('message. ' || i);
			bkr.emit_msg;
		end loop;
		bkr.stream_close;
	end;

end callout_broker_h;
/
