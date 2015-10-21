create or replace package g is

	resp_done exception;
	pragma exception_init(resp_done, -20998);

	procedure finish;

	procedure cancel;

	procedure feedback(value boolean := true);

	procedure interrupt(url varchar2);

end g;
/
