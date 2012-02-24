create or replace package fb is
	pragma serially_reusable;

	gv_succeed       boolean;
	gv_feedback_info varchar2(4000);
	gv_wizard_text   st;
	gv_wizard_url    st;

	procedure info(p_succeed boolean, p_info varchar2);

	procedure wizard(p_text varchar2, p_url varchar2);

	procedure wizard_history(p_text varchar2 := null, p_steps pls_integer := 1, p_reload boolean := false);

	procedure wizard_referer(p_text varchar2 := null);

	procedure wizard_regen_page(p_text varchar2 := null);

	procedure print_page;

end fb;
/

