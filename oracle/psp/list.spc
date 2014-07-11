create or replace package list is

	procedure cfg_init(lcss_ctx varchar2 := '');
	procedure cfg_add
	(
		class  varchar2,
		label  varchar2,
		align  varchar2 := 'center',
		width  varchar2 := null,
		style  varchar2 := null,
		format varchar2 := null
	);
	procedure cfg_cols;
	procedure cfg_ths;
	procedure cfg_cols_thead;
	procedure cfg_content
	(
		cur        in out nocopy sys_refcursor,
		fmt_date   varchar2 := null,
		group_size pls_integer := null,
		flush      pls_integer := null
	);
	procedure cfg_cur
	(
		cur        in out nocopy sys_refcursor,
		fmt_date   varchar2 := null,
		group_size pls_integer := null,
		flush      pls_integer := null
	);

end list;
/
