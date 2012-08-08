create or replace package k_gc is

	procedure touch(bsid varchar2);

	procedure clear_all_session;

	procedure login_session;

	procedure key_ver;

end k_gc;
/
