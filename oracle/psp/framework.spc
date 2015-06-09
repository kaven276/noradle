create or replace package framework is

	procedure entry
	(
		cfg_id  varchar2 := null,
		slot_id pls_integer := 1
	);

end framework;
/
