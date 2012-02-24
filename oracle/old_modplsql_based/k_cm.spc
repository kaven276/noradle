create or replace package k_cm is

	procedure login
	(
		p_user     varchar2,
		p_password varchar2
	);

end k_cm;
/

