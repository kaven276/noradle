create or replace package tree is

	procedure rc
	(
		cuts     in out nocopy st,
		cur      in out nocopy sys_refcursor,
		fmt_date varchar2 := null
	);

	procedure prc
	(
		tpl      varchar2,
		cur      in out nocopy sys_refcursor,
		fmt_date varchar2 := null,
		pretty   boolean := true,
		indent   boolean := true
	);

	procedure p
	(
		tpl    varchar2,
		cuts   in out nocopy st,
		indent boolean := true
	);

	procedure r
	(
		level pls_integer,
		cuts  in out nocopy st,
		para  st
	);

	procedure o(pretty boolean);
	procedure c;
	procedure c(cuts in out nocopy st);

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
