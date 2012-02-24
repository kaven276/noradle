create or replace package k_loadpsp authid current_user is

	procedure compile(tpl varchar2);

	procedure haml(tpl varchar2);

end k_loadpsp;
/

