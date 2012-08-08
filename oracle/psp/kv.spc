create or replace package kv authid current_user is

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

	procedure clear;

end kv;
/
