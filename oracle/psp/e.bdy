create or replace package body e is

	procedure raise
	(
		err_code pls_integer,
		err_msg  varchar2
	) is
	begin
		raise_application_error(err_code, err_msg);
	end;

	procedure chk
	(
		cond     boolean,
		err_code pls_integer,
		err_msg  varchar2
	) is
	begin
		if cond then
			raise_application_error(err_code, err_msg);
		end if;
	end;

end e;
/
