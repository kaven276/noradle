create or replace package body k_init is

	procedure by_response is
	begin
		null;
	end;

	procedure by_request is
	begin
		-- initialize package variables
		pv.headers.delete;
		pv.cookies.delete;
		pv.header_writen   := false;
		pv.allow_content   := false;
		pv.buffered_length := 0;
		pv.max_lmt         := null;
		pv.msg_stream      := false;
		pv.use_stream      := true;
		pv.content_md5     := false;
		pv.etag_md5        := false;
		pv.csslink         := null;
		pv.allow           := null;
		pv.nlbr            := chr(10);
	
		rb.charset_http := null;
		rb.charset_db   := null;
		rb.blob_entity  := null;
		rb.clob_entity  := null;
		rb.nclob_entity := null;
	
		pv.status_code := 200;
		if pv.protocol = 'http' then
			h.content_type;
		else
			h.content_type(h.mime_text, 'UTF-8');
		end if;
		output."_init"(80526);
		p.init;
	
		pv.elpl := dbms_utility.get_time;
	end;

end k_init;
/
