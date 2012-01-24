create or replace package r is

	na owa.vc_arr;
	va owa.vc_arr;

	procedure "_init"
	(
		c        in out nocopy utl_tcp.connection,
		passport pls_integer
	);

	function host_prefix return varchar2;

	function port return pls_integer;
	function method return varchar2;
	function base return varchar2;
	function dad return varchar2;
	function prog return varchar2;
	function pack return varchar2;
	function proc return varchar2;
	function path return varchar2;
	function qstr return varchar2;
	function hash return varchar2;
	function type return varchar2;

	function nc return varchar2;
	function nd return date;
	function nn return number;

	procedure setc
	(
		name  varchar2,
		value varchar2
	);

	procedure getc
	(
		name   varchar2,
		value  in out nocopy varchar2,
		defval varchar2
	);

	procedure getc
	(
		name  varchar2,
		value in out nocopy varchar2
	);

	procedure getn
	(
		name   varchar2,
		value  in out nocopy number,
		defval number,
		format varchar2 := null
	);

	procedure getn
	(
		name   varchar2,
		value  in out nocopy number,
		format varchar2 := null
	);

	procedure getd
	(
		name   varchar2,
		value  in out nocopy date,
		defval date,
		format varchar2 := null
	);

	procedure getd
	(
		name   varchar2,
		value  in out nocopy date,
		format varchar2 := null
	);

	function getc
	(
		name   varchar2,
		defval varchar2
	) return varchar2;

	function getc(name varchar2) return varchar2;

	function getn
	(
		name   varchar2,
		defval number,
		format varchar2 := null
	) return number;

	function getn
	(
		name   varchar2,
		format varchar2 := null
	) return number;

	function getd
	(
		name   varchar2,
		defval date,
		format varchar2 := null
	) return date;

	function getd
	(
		name   varchar2,
		format varchar2 := null
	) return date;

	procedure gets
	(
		name  varchar2,
		value in out nocopy st
	);
	function gets(name varchar2) return st;

	function header(name varchar2) return varchar2;

	function user return varchar2;
	function pass return varchar2;

	procedure cgi
	(
		name  varchar2,
		value varchar2
	);

	function cgi(name varchar2) return varchar2;

	function cookie(name varchar2) return varchar2;

	function gc_msid return varchar2;
	function gc_lsid return varchar2;
	function gc_bsid return varchar2;

	function dbu return varchar2;
	function file return varchar2;

	function from_prog return varchar2;
	function url return varchar2;

	function gu_dad_path return varchar2;
	-- function gu_full_base return varchar2;

	function etag return varchar2;
	function lmt return date;

end r;
/
