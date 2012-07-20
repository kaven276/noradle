create or replace package k_dco_adm is

	procedure wait_reconnect_exthub
	(
		host   varchar2,
		port   number,
		unused boolean := false
	);

end k_dco_adm;
/
