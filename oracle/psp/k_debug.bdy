create or replace package body k_debug is

	procedure meter
	(
		info varchar2,
		name varchar2 := 'prof'
	) is
	begin
		if dbms_utility.get_time - pv.elpl < 3 then
			return;
		end if;
		dbms_pipe.pack_message(dbms_utility.get_time - pv.elpl);
		pv.elpl := dbms_utility.get_time;
		dbms_pipe.pack_message(info);
		tmp.i := dbms_pipe.send_message(name, 0);
		if tmp.i != 0 then
			dbms_pipe.purge(name);
			dbms_pipe.reset_buffer;
		end if;
	exception
		when others then
			dbms_pipe.purge(name);
			dbms_pipe.reset_buffer;
	end;

	procedure time_header_init is
	begin
		pv.elpt := dbms_utility.get_time;
		pv.cput := dbms_utility.get_cpu_time;
		pv.tseq := 1;
	end;

	procedure time_header(name varchar2) is
		t1 number(10);
		t2 number(10);
		hn varchar2(99);
	begin
		if pv.tseq is null then
			return;
		end if;
		if pv.tseq = 1 and r.is_null('t$timespan') then
			pv.tseq := null;
			return;
		end if;
		t1 := dbms_utility.get_time;
		t2 := dbms_utility.get_cpu_time;
		hn := 'x-pw-otime-' || pv.tseq || '-' || name;
		pv.headers(hn) := ((t1 - pv.elpt) * 10) || ' / ' || ((t2 - pv.cput) * 10) || ' ms';
		pv.elpt := t1;
		pv.cput := t2;
		pv.tseq := pv.tseq + 1;
	end;

	procedure trace
	(
		info varchar2,
		name varchar2 := 'node2psp'
	) is
	begin
		dbms_pipe.pack_message(info);
		tmp.i := dbms_pipe.send_message(name, 0);
		if tmp.i != 0 then
			dbms_pipe.purge(name);
			dbms_pipe.reset_buffer;
		end if;
	exception
		when others then
			dbms_pipe.purge(name);
			dbms_pipe.reset_buffer;
	end;

	procedure trace
	(
		info st,
		name varchar2 := 'node2psp'
	) is
	begin
		for i in 1 .. info.count loop
			dbms_pipe.pack_message(info(i));
		end loop;
		tmp.i := dbms_pipe.send_message(name, 0);
		if tmp.i != 0 then
			dbms_pipe.purge(name);
			dbms_pipe.reset_buffer;
		end if;
	exception
		when others then
			dbms_pipe.purge(name);
			dbms_pipe.reset_buffer;
	end;

	procedure set_run_comment(value varchar2) is
	begin
		pv.hp_label := value;
	end;

	procedure req_info is
		n  varchar2(100);
		v  varchar2(999);
		va st;
	begin
		h.set_line_break(chr(10));
		h.line('<pre>');
	
		h.line('[ This is the basic request info derived from http request line and host http header ]');
		h.line('r.url_full : ' || r.url_full);
		h.line('r.dir_full : ' || r.dir_full);
		h.line('r.method : ' || r.method);
		h.line('r.protocol : ' || r.protocol);
		h.line('r.site : ' || r.site);
		h.line('r.host : ' || r.host);
		h.line('r.hostname : ' || r.hostname);
		h.line('r.sdns : ' || r.sdns);
		h.line('r.pdns : ' || r.pdns);
		h.line('r.port : ' || r.port);
		h.line('r.url : ' || r.url);
		h.line('r.pathname : ' || r.pathname);
		h.line('r.dir : ' || r.dir);
		h.line('r.prog : ' || r.prog);
		h.line('r.pack : ' || r.pack);
		h.line('r.proc : ' || r.proc);
		h.line('r.subpath : ' || r.subpath);
		h.line('r.qstr : ' || r.qstr);
	
		h.line;
		h.line('[ This is the basic request info derived from http header ]');
		h.line('r.ua : ' || r.ua);
		h.line('r.referer : ' || r.referer);
		h.line('r.bsid : ' || r.bsid);
		h.line('r.msid : ' || r.msid);
	
		h.line;
		h.line('[ This is about client/server address]');
		h.line('r.client_addr : ' || r.client_addr);
		h.line('r.client_port : ' || r.client_port);
		h.line('r.server_family : ' || r.server_family);
		h.line('r.server_addr : ' || r.server_addr);
		h.line('r.server_port : ' || r.server_port);
	
		h.line;
		h.line('[ This is all original http request headers exclude cookies]');
		n := ra.params.first;
		loop
			exit when n is null;
			if n like 'h$%' then
				v := ra.params(n) (1);
				h.line(n || ' : ' || v);
			end if;
			n := ra.params.next(n);
		end loop;
	
		h.line;
		h.line('[ This is all http request cookies ]');
		n := ra.params.first;
		loop
			exit when n is null;
			if n like 'c$%' then
				v := ra.params(n) (1);
				h.line(n || ' : ' || v);
			end if;
			n := ra.params.next(n);
		end loop;
	
		h.line;
		h.line('[ This is all browser session data ]');
		n := ra.params.first;
		loop
			exit when n is null;
			if n like 's$%' then
				v := ra.params(n) (1);
				h.line(n || ' : ' || v);
			end if;
			n := ra.params.next(n);
		end loop;
	
		h.line;
		h.line('[ This is all http request parameter that may be got from the following ways ]');
		h.line('query string, post with application/x-www-form-urlencoded, post with multipart/form-data');
		h.line;
		n := ra.params.first;
		loop
			exit when n is null;
			if substrb(n, 2, 1) != '$' then
				va := ra.params(n);
				h.line(n || ' : ' || t.join(va, ', '));
				for i in 1 .. va.count loop
					h.line(r.unescape(va(i)));
				end loop;
			end if;
			n := ra.params.next(n);
		end loop;
	
		h.line;
		h.line('[ This is all request name-value pairs ]');
		h.line;
		n := ra.params.first;
		loop
			exit when n is null;
			va := ra.params(n);
			h.line(n || ' : ' || t.join(va, ', '));
			n := ra.params.next(n);
		end loop;
	
		h.line('</pre>');
	end;

	procedure unit_test_init is
	begin
		pv.protocol := 'HTTP';
		k_init.by_request;
		bios.init_req_pv;
		pv.nlbr := chr(10);
		--dbms_output.enable(80000);
		htp.init;
	end;

	procedure unit_test_print is
	begin
		dbms_output.put_line('buffered in ' || t.tf(pv.pg_nchar, 'nvarchar2', 'varchar2') || chr(10));
		output.finish;
		dbms_output.new_line;
	end;

	procedure print_to_ide(str in out nocopy varchar2 character set any_cs) is
		v_len     pls_integer := length(str);
		htbuf_len pls_integer := 255;
	begin
		dbms_output.put(str);
		htp.prn(str);
	end;

end k_debug;
/
