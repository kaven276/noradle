create or replace package body any_server is

	procedure serv is
	begin	
		if substrb(nvl(r.pack, r.proc), -2) not in ('_c', '_b', '_h') then
			raise pv.ex_continue;
		end if;
	
		output."_init"(80526);
		pv.header_writen := true;
		pv.content_md5   := null;
		pv.etag_md5      := null;
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
