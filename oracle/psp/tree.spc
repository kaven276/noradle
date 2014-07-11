create or replace package tree is

	procedure cur
	(
		cuts     in out nocopy st,
		cur      in out nocopy sys_refcursor,
		fmt_date varchar2 := null
	);

	procedure o
	(
		pretty boolean,
		tags   varchar2 := 'ul,li'
	);

	procedure c;

	procedure n
	(
		level pls_integer,
		str   varchar2
	);

	procedure n
	(
		level varchar2,
		str   varchar2
	);

	procedure n(str varchar2);

end tree;
/
