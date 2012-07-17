create or replace procedure auto_stream_h authid current_user is
	v_stream_name varchar2(30) := r.getc('stream_name');
	v_handler     varchar2(92) := r.getc('handler_name', '');
begin
	mv2bg.listen(v_stream_name);
	bkr.stream_open;
	loop
		pvevk.current_event := mv2bg.read;
		exit when pvevk.current_event.evt_rowid is null;
		k_debug.trace(nvl(pvevk.current_event.req_handler, v_handler));
		execute immediate 'call ' || nvl(pvevk.current_event.req_handler, v_handler) || '()';
		bkr.emit_msg;
	end loop;
	bkr.stream_close;
end;
/
