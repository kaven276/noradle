create or replace package rs authid current_user is

	procedure print
	(
		name varchar2,
		c    in out sys_refcursor
	);

end rs;
/
