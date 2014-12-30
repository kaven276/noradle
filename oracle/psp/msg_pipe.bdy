create or replace package body msg_pipe is

	-- called from repeated NDBC call
	procedure pipe2node is
		v_pipename varchar2(100) := r.getc('pipename');
		v_timeout  number := r.getn('timeout', 2);
	begin
		tmp.n := dbms_pipe.receive_message(v_pipename, v_timeout);
		if tmp.n = 1 then
			h.status_line(400);
			h.content_type('text/plain');
			x.t('listen callout message timeout!');
			return;
		end if;
		h.content_type('text/items');
		h.set_line_break(r.getc('lb', chr(30) || chr(10)));
		loop
			case dbms_pipe.next_item_type
				when 0 then
					-- no more items
					return;
				when 6 then
					-- number
					dbms_pipe.unpack_message(tmp.n);
					h.line(to_number(tmp.n));
				when 9 then
					-- varchar2
					dbms_pipe.unpack_message(tmp.s);
					h.line(tmp.s);
				when 11 then
					-- rowid
					dbms_pipe.unpack_message(tmp.rid);
					h.line(rowidtochar(tmp.rid));
				when 12 then
					-- date
					dbms_pipe.unpack_message(tmp.dt);
					h.line(to_char(tmp.dt));
				when 23 then
					-- raw
					dbms_pipe.unpack_message(tmp.rw);
					h.line(rawtohex(tmp.rw));
				else
					null;
			end case;
		end loop;
	end;

	-- called from NDBC callback/response call
	procedure node2pipe is
		v_pipename varchar2(100) := r.getc('h$pipename');
		n          varchar2(100);
		v          varchar2(999);
		va         st;
		v_sep      varchar2(2) := ',' || chr(30);
	begin
		n := ra.params.first;
		loop
			exit when n is null;
			if lengthb(n) < 2 or substrb(n, 2, 1) != '$' then
				va := ra.params(n);
				dbms_pipe.pack_message(n);
				r.gets(n, va);
				dbms_pipe.pack_message(t.join(va, v_sep));
			end if;
			n := ra.params.next(n);
		end loop;
		tmp.n := dbms_pipe.send_message(v_pipename);
	end;

	function pipe2param
	(
		pipe    varchar2,
		timeout number
	) return boolean is
		v_sep varchar2(2) := ',' || chr(30);
		n     varchar2(100);
		v     varchar2(999);
		v_st  st;
	begin
		tmp.n := dbms_pipe.receive_message(pipe, timeout);
		if tmp.n = 1 then
			return false;
		end if;
		loop
			exit when dbms_pipe.next_item_type = 0;
			dbms_pipe.unpack_message(n);
			dbms_pipe.unpack_message(v);
			if v is null then
				v_st := st(null);
			else
				t.split(v_st, v, v_sep, false);
			end if;
			ra.params(n) := v_st;
		end loop;
		return true;
	end;

end msg_pipe;
/
