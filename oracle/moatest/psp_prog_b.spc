create or replace package psp_prog_b authid current_user is

	procedure comments_pack(p_pack varchar2);

	procedure comments_proc
	(
		p_pack varchar2,
		p_proc varchar2
	);

	procedure export;

end psp_prog_b;
/

