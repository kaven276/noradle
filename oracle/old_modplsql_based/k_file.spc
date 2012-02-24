create or replace package k_file authid definer is

	-- 文件下载命名转换，类型识别，权限控制的包

	gc_to_bfile constant boolean := true;

	-----------------------------------------------------------------

	-- 获得下一个新的文件流水号
	function get_next_file_id return number;

	---------------------------------------------------------------

	-- 根据指定的FILE_ID，返回UPLOAD_FILE_T中的name
	function id2name(p_file_id number) return varchar2;
	-----------------------------------------------------------------

	-- 根据指定的文件名，返回UPLOAD_FILE_T中的FILE_ID
	-- #param p_file     varchar2             指定的文件名
	-- #return           number               返回FILE_ID
	function name2id(p_auto_name varchar2) return number;

	-----------------------------------------------------------------

	function id2fpath(p_file_id number) return varchar2;

	-----------------------------------------------------------------

	function fpath2id(p_full_path varchar2) return number;

	------------------------------------------------------------

	-- 上传文件 trigger 用的过程
	procedure upload
	(
		p_file_id      in out nocopy binary_integer,
		p_autoname     in out nocopy varchar2,
		p_blob_content in out nocopy blob,
		p_dad_name     in out nocopy varchar2,
		p_db_user      in out nocopy varchar2,
		p_full_path    in out nocopy varchar2
	);

	procedure all_to_bfile;

	-- 执行下载功能
	-- 依据内部的文档唯一 ID 下载内容
	-- 做 id 到 psp gateway 自动生成唯一名的转换
	procedure download;

	-----------------------------------------------------------------

	-- 设置指定自动设定文件名的文件完整路径，并返回 file id
	function set_full_path
	(
		p_auto_name varchar2,
		p_file_path varchar2,
		p_file_name varchar2 := null,
		p_replace   boolean := false,
		p_suffix    varchar2 := null
	) return number;

	-----------------------------------------------------------------

	procedure set_full_path
	(
		p_file_id   number,
		p_full_path varchar2
	);

	procedure update_content
	(
		p_file_id   number,
		p_auto_name varchar2
	);

	-----------------------------------------------------------------

	-- 改变指定文件号的文件名
	procedure chg_name
	(
		p_file_id   number,
		p_file_name varchar2
	);

	-----------------------------------------------------------------

	-- 改变指定文件号的文件名
	procedure chg_path
	(
		p_file_id   number,
		p_file_path varchar2
	);

	-----------------------------------------------------------------

	-- 增加文件引用数
	procedure add_reference(p_file_id number);

	-----------------------------------------------------------------

	-- 减少文件引用数
	procedure del_reference(p_file_id number);

	-----------------------------------------------------------------

	-- 清理过期无引用文件
	procedure purge_expired(p_timeout number);

end k_file;
/

