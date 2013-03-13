create or replace package body http_server is

	procedure error_not_bch is
	begin
		if pv.msg_stream then
			h.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
		else
			h.allow_get_post;
			h.status_line(403);
			h.content_type('text/plain');
			h.header_close;
			h.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
			output.finish;
		end if;
	end;

	procedure error_invalid_dbu is
	begin
		if pv.msg_stream then
			h.line('The requested DB user "' || r.dbu || '" is not allowed to access');
		else
			h.allow_get_post;
			h.status_line(403);
			h.content_type('text/plain');
			h.header_close;
			h.line('The requested DB user "' || r.dbu || '" is not allowed to access');
			output.finish;
		end if;
	end;

	procedure onex
	(
		code number,
		errm varchar2
	) is
	begin
		if pv.msg_stream then
			h.line(r.dbu);
			h.line(r.prog);
			h.line(sqlcode);
			h.line(sqlerrm);
		else
			h.allow_get_post;
			h.status_line(500);
			h.content_type('text/plain');
			h.header_close;
			h.line('in servlet occurred dyna sp call error for dbu : ' || r.dbu);
			h.line('error text = ' || code || '/' || errm);
		end if;
	end;

	procedure serv is
		v_dbuf server_control_t.dbu_filter%type;
	begin
		k_init.by_request;
		r."_init"(pv.c, 80526);
		k_gc.touch(r.bsid);
	
		v_dbuf := k_cfg.server_control().dbu_filter;
		if v_dbuf is not null and not regexp_like(r.dbu, v_dbuf) then
			raise pv.ex_continue;
		end if;
	
		if substrb(nvl(r.pack, r.proc), -2) not in ('_c', '_b', '_h') then
			error_not_bch;
			raise pv.ex_continue;
		end if;
	
		dbms_application_info.set_module(r.prog, null);
	
	end;

end http_server;
/
