create or replace package rs authid current_user is

	procedure print
	(
		name varchar2,
		c    in out sys_refcursor
	);

	procedure print(c in out sys_refcursor);

	procedure use_remarks;

end rs;
/
