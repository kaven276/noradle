create or replace package multi is

	function w
	(
		head  varchar2,
		texts st,
		tail  varchar2
	) return varchar2;
	procedure w
	(
		head   varchar2,
		texts  st,
		tail   varchar2,
		indent boolean := true
	);

	function w
	(
		tpl   varchar2,
		texts st
	) return varchar2;
	procedure w
	(
		tpl    varchar2,
		texts  st,
		indent boolean := true
	);

	function w
	(
		tpl   varchar2,
		texts varchar2
	) return varchar2;
	procedure w
	(
		tpl    varchar2,
		texts  varchar2,
		indent boolean := true
	);

	procedure nv
	(
		tpl    varchar2,
		cur    sys_refcursor,
		sv     varchar2,
		indent boolean := true
	);
	function nv
	(
		tpl varchar2,
		cur sys_refcursor,
		sv  varchar2
	) return varchar2;

	procedure nv
	(
		tpl    varchar2,
		ns     st,
		vs     st,
		sv     varchar2,
		indent boolean := true
	);

	procedure prc
	(
		tpl      varchar2,
		cur      in out nocopy sys_refcursor,
		fmt_date varchar2 := null,
		flush    pls_integer := null
	);

	procedure p
	(
		tpl    varchar2,
		cuts   in out nocopy st,
		indent boolean := true
	);
	procedure r
	(
		cuts in out nocopy st,
		para st
	);
	function r
	(
		cuts in out nocopy st,
		para st
	) return varchar2;

end multi;
/
