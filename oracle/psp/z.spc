create or replace package z is

	p pv.vc_arr;

	procedure t
	(
		tag   varchar2,
		inner varchar2 := chr(0)
	);

	procedure u
	(
		tag   varchar2,
		url   varchar2,
		inner varchar2 := chr(0)
	);

	function u
	(
		tag   varchar2,
		url   varchar2,
		inner varchar2 := chr(0)
	) return varchar2;

	procedure v
	(
		tag    varchar2,
		value  varchar2,
		switch boolean := null
	);

	function v
	(
		tag    varchar2,
		value  varchar2,
		switch boolean := null
	) return varchar2;

	procedure v
	(
		tag    varchar2,
		value  varchar2,
		inner  varchar2,
		switch boolean := null
	);

	function v
	(
		tag    varchar2,
		value  varchar2,
		inner  varchar2,
		switch boolean := null
	) return varchar2;

end z;
/
