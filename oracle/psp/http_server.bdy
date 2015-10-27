create or replace package body http_server is

	procedure error_not_bch is
	begin
		if pv.msg_stream then
			b.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
		else
			h.allow_get_post;
			h.status_line(403);
			h.content_type('text/plain');
			h.header_close;
			b.line('The requested program unit is "' || r.prog || '" , only _b/_c/_h named unit can be called from http');
			output.finish;
		end if;
	end;

	procedure error_invalid_dbu is
	begin
		if pv.msg_stream then
			b.line('The requested DB user "' || r.dbu || '" is not allowed to access');
		else
			h.allow_get_post;
			h.status_line(403);
			h.content_type('text/plain');
			h.header_close;
			b.line('The requested DB user "' || r.dbu || '" is not allowed to access');
			output.finish;
		end if;
	end;

	procedure serv is
	begin
		r."_init"(pv.c, 80526);
		k_init.by_request;
		style.init_by_request;
		dbms_session.set_identifier(r.bsid);
	
		if false and substrb(nvl(r.pack, r.proc), -2) not in ('_c', '_b', '_h') then
			error_not_bch;
			raise pv.ex_continue;
		end if;
	
		dbms_application_info.set_action(r.prog);
	end;

end http_server;
/
