create or replace package body k_init is

	procedure by_response is
	begin
		null;
	end;

	procedure header_init is
	begin
		pv.headers.delete;
		pv.cookies.delete;
		pv.status_code   := 200;
		pv.header_writen := false;
		pv.content_md5   := false;
		pv.etag_md5      := false;
		pv.max_lmt       := null;
		pv.allow         := null;
		pv.nlbr          := chr(10);
	
		if pv.protocol = 'HTTP' then
			h.content_type;
		else
			h.content_type(h.mime_text, 'UTF-8');
		end if;
		h.content_encoding_auto;
	end;

	procedure by_request is
	begin
		-- initialize output flow control pv   
		pv.msg_stream := false;
		pv.use_stream := true;
		pv.feedback   := null;
		pv.bom        := null;
	
		header_init;
		p.init;
		pv.elpl := dbms_utility.get_time;
	end;

end k_init;
/
