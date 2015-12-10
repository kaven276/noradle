create or replace package ztag is

	procedure p
	(
		idx pls_integer,
		val varchar2
	);

	procedure p
	(
		idx pls_integer,
		val boolean
	);

	procedure p
	(
		idx pls_integer,
		val number
	);

	procedure t
	(
		tag   varchar2,
		inner varchar2 := chr(0)
	);

	function t
	(
		tag   varchar2,
		inner varchar2 := chr(0)
	) return varchar2;

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

	procedure c(comment varchar2);

	procedure d
	(
		unit varchar2,
		line varchar2
	);

end ztag;
/
