create or replace package body post_b is

	procedure order_form is
	begin
		null;
		-- this form will borrow book from library
		-- but some items may be 404 not found
		-- some books may be unavailable
		-- some books may not allowed to borrow
		-- and some book is gone
		-- if ok, it will use 303 feedback page to show
		-- if err, it will show error msg directly
	end;

	procedure echo_body is
	begin
		if r.is_lack('clob') then
			h.download(rb.blob_entity);
		else
			k_debug.trace(st('echo body for clob'));
			r.body2clob;
			h.download(rb.clob_entity);
		end if;
	end;

end post_b;
/
