create or replace package r is

	procedure "_init"(c in out nocopy utl_tcp.connection, passport pls_integer);

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

end r;
/

