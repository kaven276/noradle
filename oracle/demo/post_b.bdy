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
		r.body2clob;
		h.write(dbms_lob.substr(rb.clob_entity, 1000));
	end;

end post_b;
/
