create or replace package k_gw authid current_user is
	pragma serially_reusable;

	procedure do; -- must be the first sub-proc in the list(maybe oracle bug)

	procedure cancel_page(p_commit boolean := false);

	procedure assert(p_info varchar2);

	procedure feedback;

	procedure trace(info varchar2);

	procedure trace(info st);

end k_gw;
/

