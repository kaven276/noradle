create or replace package e is

	procedure raise
	(
		err_code pls_integer,
		err_msg  varchar2
	);

	procedure chk
	(
		cond     boolean,
		err_code pls_integer,
		err_msg  varchar2
	);

	procedure report
	(
		cond boolean,
		msg  varchar2
	);

end e;
/
