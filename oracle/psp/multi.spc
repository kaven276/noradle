create or replace package multi is

	function w(head varchar2, texts st, tail varchar2) return varchar2;
	procedure w(head varchar2, texts st, tail varchar2, indent boolean := true);

	function w(tpl varchar2, texts st) return varchar2;
	procedure w(tpl varchar2, texts st, indent boolean := true);

	function w(tpl varchar2, texts varchar2) return varchar2;
	procedure w(tpl varchar2, texts varchar2, indent boolean := true);

	procedure w(tpl varchar2, cur sys_refcursor, sv varchar2, indent boolean := true);
	function w(tpl varchar2, cur sys_refcursor, sv varchar2) return varchar2;

	procedure c(tpl varchar2, cur in out nocopy sys_refcursor, fmt_date varchar2 := null);

	procedure p(tpl varchar2, cuts in out nocopy st, indent boolean := true);
	procedure r(cuts in out nocopy st, para st);

	procedure p(tpl varchar2, list_tag varchar2, cuts in out nocopy st, indent boolean := true);
	procedure r(cuts in out nocopy st, level pls_integer, para st);
	procedure ro(pretty boolean := null);
	procedure rc(cuts in out nocopy st);

end multi;
/
