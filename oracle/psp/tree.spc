create or replace package tree is

	procedure content
	(
		cuts     in out nocopy st,
		cur      in out nocopy sys_refcursor,
		fmt_date varchar2 := null
	);

end tree;
/
