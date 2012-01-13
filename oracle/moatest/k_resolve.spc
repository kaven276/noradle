create or replace package k_resolve is

	-- todo: change to revoker right
	-- todo: use package variable to hold result instead of out parameter
	-- todo: set it as a hook proc, choose between authorize proc or authenticate proc

	procedure resolve_prog
	(
		p_name   varchar2,
		p_schema out varchar2,
		p_pack   out varchar2,
		p_proc   out varchar2
	);

	procedure resolve_prog
	(
		p_name   varchar2,
		p_schema out varchar2,
		p_prog   out varchar2
	);

end k_resolve;
/

