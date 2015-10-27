create or replace package g is

	resp_done exception;
	pragma exception_init(resp_done, -20998);

	procedure finish;

	procedure cancel;

	procedure feedback(value boolean := true);

	procedure interrupt(url varchar2);

	procedure alert_go
	(
		text varchar2,
		url  varchar2
	);

	procedure alert_back
	(
		text      varchar2,
		back_step pls_integer := 1
	);

end g;
/
