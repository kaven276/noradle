create or replace package k_exception is

	-- Author  : 王景欣
	-- Created : 2006-5-29
	-- Purpose : 处理系统错误

	e_user_error exception;

	e_job_error exception;

	pragma exception_init(e_user_error, -20999);

	pragma exception_init(e_job_error, -20000);

	gc_user_error constant pls_integer := -20999;

	gc_job_error constant pls_integer := -20000;

	function ex_msg return varchar2;

	------------------------------------------------------------------------------------

	--记录用户处理的异常（待字符串全部资源化后将被废止掉）
	--#usage  用户调用
	--#param p_business_cls 业务错误分类标识，用于事后的统计和管理
	--#param p_software_cls 通用软件错误分类标识，用于事后的统计和管理
	--#param p_cust_errm 用户定义的错误信息
	procedure raise
	(
		p_business_cls varchar2,
		p_software_cls varchar2,
		p_cust_errm    varchar2,
		p_must_log     boolean default false
	);

end k_exception;
/

