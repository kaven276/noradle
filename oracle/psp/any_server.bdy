create or replace package body any_server is

	procedure serv is
		v_dbuf server_control_t.dbu_filter%type;
	begin
		pv.schema := utl_tcp.get_line(pv.c, true);
		pv.prog   := utl_tcp.get_line(pv.c, true);
		v_dbuf    := k_cfg.server_control().dbu_filter;
		if v_dbuf is not null and not regexp_like(r.dbu, v_dbuf) then
			raise pv.ex_continue;
		end if;
	
		if substrb(nvl(r.pack, r.proc), -2) not in ('_c', '_b', '_h') then
			raise pv.ex_continue;
		end if;
	
		output."_init"(80526);
		p.init;
		pv.header_writen := true;
		pv.content_md5   := null;
		pv.etag_md5      := null;
		pv.csslink       := null;
	end;

	procedure onex
	(
		code number,
		errm varchar2
	) is
	begin
		null;
	end;

end any_server;
/
