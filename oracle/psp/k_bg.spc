create or replace package k_bg authid current_user is

	procedure do(p_prog varchar2);

end k_bg;
/
