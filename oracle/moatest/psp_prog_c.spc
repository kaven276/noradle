create or replace package psp_prog_c authid current_user is

	procedure comments_pack
	(
		p_pack     varchar2,
		p_brief    varchar2,
		p_comments varchar2
	);

	procedure comments_proc
	(
		p_pack     varchar2,
		p_proc     varchar2,
		p_brief    varchar2,
		p_comments varchar2
	);

end psp_prog_c;
/

