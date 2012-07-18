create or replace package body callout_broker_h is

	procedure emit_messages is
		-- simple message stream, emit ascending numbers at 1s interval
	begin
		bkr.stream_open;
		for i in 1 .. 3 loop
			dbms_lock.sleep(1);
			h.line('message. ' || i);
			bkr.emit_msg;
		end loop;
		bkr.stream_close;
	end;

	procedure user_change_handler is
		evt mv2bg.event;
		v   user_t%rowtype;
	begin
		mv2bg.get(evt);
		select a.* into v from user_t a where a.rowid = evt.evt_rowid;
		h.line('user:pass is ' || v.name || ':' || v.pass);
	end;

	procedure user_change_manual_stream is
		-- use mv2bg.write_event mv2bg.read_event and application logic to product message stream
		ev mv2bg.event;
		v  user_t%rowtype;
	begin
		mv2bg.listen('user_change_broker');
		bkr.stream_open;
		loop
			ev := mv2bg.read;
			exit when ev.evt_rowid is null;
			select a.* into v from user_t a where a.rowid = ev.evt_rowid;
			h.line('user:pass is ' || v.name || ':' || v.pass);
			bkr.emit_msg;
		end loop;
		bkr.stream_close;
	end;

	procedure sms is
	begin
		bkr.stream_open;
		for i in 1 .. 3 loop
			h.line('AAAS2sAAEAAACEjAAA');
			h.line(1); -- number of target numbers
			h.line('15620001781,Li Yong' || i);
			h.line('Hello,:1. Do you known Noradle is for NodeJS&Oracle integration?');
			h.line('ReportFlag:1');
			bkr.emit_msg;
			dbms_lock.sleep(5);
		end loop;
		bkr.stream_close;
	end;

end callout_broker_h;
/
