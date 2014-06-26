create or replace package gateway is

	procedure listen
	(
		cfg_id  varchar2 := null,
		slot_id pls_integer := 1
	);

end gateway;
/
