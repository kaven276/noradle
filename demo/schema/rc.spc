create or replace package rc is

	procedure set_user_info(p_username varchar2);

	procedure set_term_info(p_msid varchar2);

end rc;
/
