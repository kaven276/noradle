create or replace package g is

	procedure finish;

	procedure cancel;

	procedure filter_pass;

	procedure feedback(value boolean := true);

	procedure interrupt(url varchar2);

end g;
/
