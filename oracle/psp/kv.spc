create or replace package kv is

	procedure set
	(
		type varchar2,
		key  varchar2,
		ver  varchar2
	);

	function get
	(
		type varchar2,
		key  varchar2
	) return varchar2;

	procedure del
	(
		type varchar2,
		key  varchar2
	);

end kv;
/
