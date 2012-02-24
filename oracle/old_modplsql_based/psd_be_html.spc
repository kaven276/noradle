create or replace package psd_be_html is

	function linkto
	(
		p_caption   varchar2,
		p_object    varchar2 := null,
		p_oowner    varchar2 := null,
		p_oname     varchar2 := null,
		p_otype     varchar2 := null,
		p_subobject varchar2 := null,
		p_username  varchar2 := null
	) return varchar2;

	procedure all_in_one
	(
		p_object    varchar2 := null,
		p_oowner    varchar2 := null,
		p_oname     varchar2 := null,
		p_otype     varchar2 := null,
		p_subobject varchar2 := null,
		p_username  varchar2 := null
	);

end psd_be_html;
/

