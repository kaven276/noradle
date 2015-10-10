create or replace package rs authid current_user is

	procedure print
	(
		name varchar2,
		c    in out sys_refcursor
	);

	procedure print(c in out sys_refcursor);

	procedure json(c in out sys_refcursor);

	procedure use_remarks;

	procedure nv
	(
		n varchar2,
		v varchar2
	);

	procedure nv
	(
		n varchar2,
		v number
	);

	procedure nv
	(
		n varchar2,
		v date
	);

	procedure nv
	(
		n varchar2,
		v boolean
	);

end rs;
/
