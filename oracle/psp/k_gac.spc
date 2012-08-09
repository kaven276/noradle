create or replace package k_gac authid current_user is

	procedure set
	(
		ctx   varchar2,
		attr  varchar2,
		value varchar2
	);

	procedure rm
	(
		ctx  varchar2,
		attr varchar2
	);

	procedure rm(ctx varchar2);

	procedure gset
	(
		ctx   varchar2,
		attr  varchar2,
		value varchar2
	);

	procedure gsetn
	(
		ctx   varchar2,
		attr  varchar2,
		value number
	);

	procedure gsetd
	(
		ctx   varchar2,
		attr  varchar2,
		value date
	);

	procedure grm
	(
		ctx  varchar2,
		attr varchar2
	);

	procedure grm(ctx varchar2);

	function get
	(
		ctx  varchar2,
		attr varchar2
	) return varchar2;

	function getn
	(
		ctx  varchar2,
		attr varchar2
	) return number;

	function getd
	(
		ctx  varchar2,
		attr varchar2
	) return date;

end k_gac;
/
