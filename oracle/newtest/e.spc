create or replace package e is

	procedure chk
	(
		cond     boolean,
		err_code pls_integer,
		err_msg  varchar2
	);

end e;
/
