create or replace package g is

	procedure finish;

	procedure filter_pass;

	procedure interrupt(url varchar2);

end g;
/
