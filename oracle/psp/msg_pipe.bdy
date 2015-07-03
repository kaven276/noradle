create or replace package body msg_pipe is

	-- called from repeated NDBC call
	procedure pipe2node is
		v_pipename varchar2(100) := r.getc('pipename');
		v_timeout  number := r.getn('timeout', 2);
	begin
		tmp.n := dbms_pipe.receive_message(v_pipename, v_timeout);
		if tmp.n = 1 then
			h.status_line(504);
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
		dbms_pipe.reset_buffer;
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
		pipe    varchar2 := null,
		timeout number := null
	) return boolean is
		v_sep varchar2(2) := ',' || chr(30);
		n     varchar2(100);
		v     varchar2(999);
		v_st  st;
	begin
		tmp.n := dbms_pipe.receive_message(nvl(pipe, r.cfg || '.' || r.slot), nvl(timeout, 3));
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

	procedure begin_msg(nlbr varchar2 := null) is
	begin
		dbms_pipe.reset_buffer;
		if pv.pg_buf is not null or pv.ph_buf is not null then
			output.switch;
			if pv.pg_nchar then
				pv.pg_buf := '';
			else
				pv.ph_buf := '';
			end if;
		end if;
		pv.pg_idxsp := pv.pg_index;
		pv.pg_lensp := pv.pg_len;
		pv.nlbr0    := pv.nlbr;
		pv.nlbr     := nvl(nlbr, chr(30) || chr(10));
	end;

	procedure set_callback_pipename(pipename varchar2 := null) is
	begin
		h.header('Callback-Pipename', nvl(pipename, r.cfg || '.' || r.slot));
	end;

	procedure send_msg(pipe varchar2 := null) is
		v_rtn integer;
		n     varchar2(100);
		v     varchar2(800);
	begin
		-- write headers
		n := pv.mp_headers.first;
		loop
			exit when n is null;
			v := pv.mp_headers(n);
			dbms_pipe.pack_message(n);
			dbms_pipe.pack_message(v);
			n := pv.mp_headers.next(n);
		end loop;
		pv.mp_headers.delete;
	
		-- write end of header
		dbms_pipe.pack_message('');
		dbms_pipe.pack_message(t.tf(pv.pg_nchar, 'Y', 'N'));
	
		-- write buffered output for message
		if pv.pg_nchar then
			for i in pv.pg_idxsp + 1 .. pv.pg_index loop
				dbms_pipe.pack_message(pv.pg_parts(i));
			end loop;
			-- warning: avoid double convert at message print out
			if false and pv.pg_conv then
				pv.pg_buf := convert(pv.pg_buf, pv.charset_ora, pv.cs_nchar);
			end if;
			dbms_pipe.pack_message(pv.pg_buf);
		else
			for i in pv.pg_idxsp + 1 .. pv.pg_index loop
				dbms_pipe.pack_message(pv.ph_parts(i));
			end loop;
			dbms_pipe.pack_message(pv.ph_buf);
		end if;
	
		-- send out
		v_rtn := dbms_pipe.send_message(nvl(pipe, 'nd$' || r.dbu), 1);
		if v_rtn != 0 then
			raise_application_error(-20999, 'send callout pipe message error ' || v_rtn);
		end if;
	
		-- restore
		pv.pg_index := pv.pg_idxsp;
		pv.pg_len   := pv.pg_lensp;
		pv.pg_idxsp := null;
		pv.pg_lensp := null;
		if pv.pg_nchar then
			pv.pg_buf := '';
		else
			pv.ph_buf := '';
		end if;
		pv.nlbr := pv.nlbr0;
	
	end;

	procedure fetch_msg is
		v_pipename varchar2(100) := nvl(r.getc('h$pipename'), 'nd$' || r.dbu);
		v_timeout  number := r.getn('h$timeout', 3);
		v_headover boolean := false;
		n          varchar2(100);
		v          varchar2(4000);
		v_nchar    char(1);
		v_chunk    varchar2(32767);
		v_nchunk   nvarchar2(32767);
	begin
		tmp.n := dbms_pipe.receive_message(v_pipename, v_timeout);
		if tmp.n = 1 then
			h.status_line(504);
			h.content_type('text/plain');
			x.t('listen callout message timeout over ' || v_timeout || ' seconds!');
			return;
		end if;
	
		h.content_type('text/plain');
		loop
			exit when dbms_pipe.next_item_type = 0;
			if v_headover then
				if v_nchar = 'Y' then
					dbms_pipe.unpack_message(v_nchunk);
					output.line(v_nchunk, '', null);
				else
					dbms_pipe.unpack_message(v_chunk);
					output.line(v_chunk, '', null);
				end if;
			else
				dbms_pipe.unpack_message(n);
				if n is null then
					v_headover := true;
					dbms_pipe.unpack_message(v_nchar);
					continue;
				end if;
				dbms_pipe.unpack_message(v);
				h.header(n, v);
			end if;
		end loop;
	end;

end msg_pipe;
/
