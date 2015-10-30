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
		if pv.tseq = 1 and r.getc('t$', 'false') = 'false' then
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
		b.set_line_break(chr(10));
		b.line('<pre>');
	
		b.line('[ This is the basic request info derived from http request line and host http header ]');
		b.line('r.url_full : ' || r.url_full);
		b.line('r.dir_full : ' || r.dir_full);
		b.line('r.method : ' || r.method);
		b.line('r.protocol : ' || r.protocol);
		b.line('r.site : ' || r.site);
		b.line('r.host : ' || r.host);
		b.line('r.hostname : ' || r.hostname);
		b.line('r.sdns : ' || r.sdns);
		b.line('r.pdns : ' || r.pdns);
		b.line('r.port : ' || r.port);
		b.line('r.url : ' || r.url);
		b.line('r.pathname : ' || r.pathname);
		b.line('r.dir : ' || r.dir);
		b.line('r.prog : ' || r.prog);
		b.line('r.pack : ' || r.pack);
		b.line('r.proc : ' || r.proc);
		b.line('r.subpath : ' || r.subpath);
		b.line('r.qstr : ' || r.qstr);
	
		b.line;
		b.line('[ This is the basic request info derived from http header ]');
		b.line('r.ua : ' || r.ua);
		b.line('r.referer : ' || r.referer);
		b.line('r.bsid : ' || r.bsid);
		b.line('r.msid : ' || r.msid);
	
		b.line;
		b.line('[ This is about client/server address]');
		b.line('r.client_addr : ' || r.client_addr);
		b.line('r.client_port : ' || r.client_port);
		b.line('r.server_family : ' || r.server_family);
		b.line('r.server_addr : ' || r.server_addr);
		b.line('r.server_port : ' || r.server_port);
	
		b.line;
		b.line('[ This is all original http request headers exclude cookies]');
		n := ra.params.first;
		loop
			exit when n is null;
			if n like 'h$%' then
				v := ra.params(n) (1);
				b.line(n || ' : ' || v);
			end if;
			n := ra.params.next(n);
		end loop;
	
		b.line;
		b.line('[ This is all http request cookies ]');
		n := ra.params.first;
		loop
			exit when n is null;
			if n like 'c$%' then
				v := ra.params(n) (1);
				b.line(n || ' : ' || v);
			end if;
			n := ra.params.next(n);
		end loop;
	
		b.line;
		b.line('[ This is all browser session data ]');
		n := ra.params.first;
		loop
			exit when n is null;
			if n like 's$%' then
				v := ra.params(n) (1);
				b.line(n || ' : ' || v);
			end if;
			n := ra.params.next(n);
		end loop;
	
		b.line;
		b.line('[ This is all http request parameter that may be got from the following ways ]');
		b.line('query string, post with application/x-www-form-urlencoded, post with multipart/form-data');
		b.line;
		n := ra.params.first;
		loop
			exit when n is null;
			if substrb(n, 2, 1) != '$' then
				va := ra.params(n);
				b.line(n || ' : ' || t.join(va, ', '));
				for i in 1 .. va.count loop
					b.line(r.unescape(va(i)));
				end loop;
			end if;
			n := ra.params.next(n);
		end loop;
	
		b.line;
		b.line('[ This is all request name-value pairs ]');
		b.line;
		n := ra.params.first;
		loop
			exit when n is null;
			va := ra.params(n);
			b.line(n || ' : ' || t.join(va, ', '));
			n := ra.params.next(n);
		end loop;
	
		b.line('</pre>');
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
		--dbms_output.put_line(lengthb(str) || ',' || length(str) || '; ' || t.tf(length(str) = length4(str), '=', '!='));
		dbms_output.put(str);
		htp.prn(str);
		return;
		dbms_output.put_line(v_len || ', ' || ceil(v_len / htbuf_len));
		for i in 1 .. ceil(v_len / htbuf_len) loop
			dbms_output.put_line(i);
			dbms_output.put_line(substr(str, (i - 1) * htbuf_len + 1, htbuf_len));
			htp.prn(substr(str, (i - 1) * htbuf_len + 1, htbuf_len));
		end loop;
		-- htp.prn(str);
		-- htp.prn(substr(str, 1, 400));
	end;

end k_debug;
/
