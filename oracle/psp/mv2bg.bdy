create or replace package body mv2bg is

	procedure add(v event) is
	begin
		pvevk.pendings.extend;
		pvevk.pendings(pvevk.pendings.count) := v;
	end;

	procedure after_commit is
		v event;
	begin
		for i in 1 .. pvevk.pendings.count loop
			v := pvevk.pendings(i);
			write(v.pipe_name, v);
		end loop;
		pvevk.pendings.delete;
	end;

	procedure after_rollback is
	begin
		pvevk.pendings.delete;
	end;

	procedure write
	(
		broker varchar2,
		v      event
	) is
	begin
		dbms_pipe.pack_message(v.req_handler);
		dbms_pipe.pack_message(v.evt_table);
		dbms_pipe.pack_message_rowid(v.evt_rowid);
		dbms_pipe.pack_message(v.evt_type);
		dbms_pipe.pack_message(v.res_handler);
		tmp.n := dbms_pipe.send_message(broker);
	end;

	procedure stop(broker varchar2) is
	begin
		dbms_alert.signal(broker, '');
		commit;
	end;

	-- private
	function wait_stop_event return number is
		v_message varchar2(1);
		v_status  number;
	begin
		dbms_alert.waitone(pvevk.stream_name, v_message, v_status, 0);
		return v_status;
	end;

	procedure listen(stream_name varchar2 := null) is
	begin
		pvevk.stream_name := nvl(stream_name, r.dbu || '.' || r.prog);
		dbms_alert.register(pvevk.stream_name);
	end;

	function read return event is
		v_result integer;
		v        event;
	begin
		<<retry>>
		if wait_stop_event = 0 then
			return v;
		end if;
		v_result := dbms_pipe.receive_message(pvevk.stream_name, 3);
		if v_result = 0 then
			dbms_pipe.unpack_message(v.req_handler);
			dbms_pipe.unpack_message(v.evt_table);
			dbms_pipe.unpack_message_rowid(v.evt_rowid);
			dbms_pipe.unpack_message(v.evt_type);
			dbms_pipe.unpack_message(v.res_handler);
			return v;
		elsif v_result = 1 then
			v.evt_rowid := null; -- timeout, no more event
			goto retry;
		else
			e.raise(-20022, 'dbms_pipe.receive_message error for broker ' || pvevk.stream_name);
		end if;
	end;

	procedure get(evt in out nocopy event) is
	begin
		evt := pvevk.current_event;
	end;

end mv2bg;
/
