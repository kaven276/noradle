create or replace package body mv2bg is

	procedure add_event(v event) is
	begin
		pvevk.pendings.extend;
		pvevk.pendings(pvevk.pendings.count) := v;
	end;

	procedure after_commit is
		v event;
	begin
		for i in 1 .. pvevk.pendings.count loop
			v := pvevk.pendings(i);
			write_event(v.pipe_name, v);
		end loop;
		pvevk.pendings.delete;
	end;

	procedure after_rollback is
	begin
		pvevk.pendings.delete;
	end;

	procedure write_event
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
		v event;
	begin
		write_event(broker, v);
	end;

	procedure wait_event(stream_name varchar2 := null) is
		v_broker  varchar2(99) := nvl(stream_name, r.dbu || '.' || r.prog);
		v_message varchar2(1);
		v_status  number;
	begin
		dbms_alert.waitone(stream_name, v_message, v_status, 1000);
	end;

	function read_event(stream_name varchar2 := null) return event is
		v_broker varchar2(99) := nvl(stream_name, r.dbu || '.' || r.prog);
		v_result integer;
		v        event;
		v_rowid  rowid;
	begin
		v_result := dbms_pipe.receive_message(v_broker);
		k_debug.trace(v_result);
		if v_result = 0 then
			dbms_pipe.unpack_message(v.req_handler);
			dbms_pipe.unpack_message(v.evt_table);
			dbms_pipe.unpack_message_rowid(v.evt_rowid);
			dbms_pipe.unpack_message(v.evt_type);
			dbms_pipe.unpack_message(v.res_handler);
			return v;
		elsif v_result = 1 then
			v.evt_rowid := null; -- timeout, no more event
			return v;
		else
			e.raise(-20022, 'dbms_pipe.receive_message error for broker ' || v_broker);
		end if;
	end;

	procedure auto_stream(stream_name varchar2 := r.getc('stream_name')) is
		v event;
	begin
		bkr.stream_open;
		loop
			loop
				v := read_event(stream_name);
				exit when v.req_handler is null;
				execute immediate v.req_handler || '(:1,:2,:3,:4)'
					using v.evt_table, v.evt_rowid, v.evt_type, v.res_handler;
				bkr.emit_msg;
			end loop;
		end loop;
		bkr.stream_close;
	end;

end mv2bg;
/
