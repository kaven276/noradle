create or replace package g is

	procedure finish;

	procedure filter_pass;

	procedure feedback;

	procedure interrupt(url varchar2);

end g;
/
