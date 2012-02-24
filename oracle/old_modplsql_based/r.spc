create or replace package r is

	na owa.vc_arr;
	va owa.vc_arr;

	function nc return varchar2;

	function nd return date;

	function nn return number;

	function path_compact_level return varchar2;

	procedure init(na owa.vc_arr, va owa.vc_arr);

	procedure init_from_url(p_url varchar2);

	procedure init_from_pipe;

	procedure setc(name varchar2, value varchar2);

	procedure getc(name varchar2, value in out nocopy varchar2, defval varchar2);

	procedure getc(name varchar2, value in out nocopy varchar2);

	procedure getn(name varchar2, value in out nocopy number, defval number, format varchar2 := null);

	procedure getn(name varchar2, value in out nocopy number, format varchar2 := null);

	procedure getd(name varchar2, value in out nocopy date, defval date, format varchar2 := null);

	procedure getd(name varchar2, value in out nocopy date, format varchar2 := null);

	function getc(name varchar2, defval varchar2) return varchar2;

	function getc(name varchar2) return varchar2;

	function getn(name varchar2, defval number, format varchar2 := null) return number;

	function getn(name varchar2, format varchar2 := null) return number;

	function getd(name varchar2, defval date, format varchar2 := null) return date;

	function getd(name varchar2, format varchar2 := null) return date;

	procedure gets(name varchar2, value in out nocopy st);
	function gets(name varchar2) return st;

	procedure cgi(name varchar2, value varchar2);

	function cgi(name varchar2) return varchar2;

	function cookie(name varchar2) return varchar2;

	function gc_msid return varchar2;

	function gc_lsid return varchar2;

	function gc_bsid return varchar2;

	function prog return varchar2;

	function pack return varchar2;

	function proc return varchar2;

	function file return varchar2;

	function from_prog return varchar2;

	function dbu return varchar2;

	function dad return varchar2;

	function dad_path return varchar2;

	-- function full_base return varchar2;

	function url return varchar2;

	function pw_path_prefix return varchar2;

	function etag return varchar2;

	function lmt return varchar2;

end r;
/

