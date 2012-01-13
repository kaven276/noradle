create or replace package body k_exception is

	-----------------------------------------------------------------------------------

	-- public
	--只保留显示给用户的错误提示信息
	function ex_msg return varchar2 is
	begin
		return substr(sqlerrm, 12);
	end;

	--------------------------------------------------------------------------------------------------

	-- public
	procedure raise
	(
		p_business_cls varchar2,
		p_software_cls varchar2,
		p_cust_errm    varchar2,
		p_must_log     boolean default false
	) is
	begin
		raise_application_error(gc_user_error, p_cust_errm);
	end;

end k_exception;
/

