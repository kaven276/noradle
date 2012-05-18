create or replace package body k_broker is

	procedure stream_open is
	begin
		e.chk(r.type != 'h', -20025, 'only _h layer prog unit could be used for message stream producer');
		if pv.call_type = 0 then
			h.content_type('text/html', 'UTF-8');
			h.transfer_encoding_chunked;
			pv.use_stream := false;
			h.line('<pre>');
		else
			h.content_type('text/noradle.msg.stream', 'UTF-8');
			h.transfer_encoding_identity;
		end if;
		pv.use_stream := false;
		pv.msg_stream := true;
		output.finish;
		pv.buffered_length := 0;
		p.init;
	end;

	procedure stream_close is
		v_wlen pls_integer;
	begin
		-- write blob buffer 0 length, 
		-- g.finish;
		-- quit process will do end signal also, so nothing need to do
		if pv.call_type = 0 then
			v_wlen := utl_tcp.write_line(pv.c, '</pre>' || pv.end_marker);
			utl_tcp.flush(pv.c);
		end if;
	
	end;

	procedure emit_msg is
		v_wlen pls_integer;
	begin
		if p.gv_xhtp then
			p.ensure_close;
		end if;
		if pv.buffered_length > 0 then
			if pv.call_type = 1 then
				v_wlen := utl_tcp.write_raw(pv.c, utl_raw.cast_from_binary_integer(pv.buffered_length), 4);
			else
				v_wlen := utl_tcp.write_line(pv.c, to_char(pv.buffered_length));
			end if;
			output.do_write(pv.buffered_length, false);
			pv.buffered_length := 0;
		end if;
		p.init;
	end;

end k_broker;
/
