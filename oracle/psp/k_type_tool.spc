create or replace package k_type_tool is

	type str_arr is table of varchar2(1000) index by varchar2(100);
	type st_arr is table of st index by varchar2(100);

	type col is record(
		item varchar2(2000));

	function d2s(p_date date) return varchar2;
	function dt2s(p_date date) return varchar2;
	function s2d(p_date varchar2) return date;
	function s2dt(p_date varchar2) return date;
	function hdt2s(p_date date := sysdate) return varchar2;
	function s2hdt(p_date varchar2) return date;

	procedure half
	(
		p_str   varchar2 character set any_cs,
		p_left  in out nocopy varchar2 character set p_str%charset,
		p_right in out nocopy varchar2 character set p_str%charset
	);

	function gen_token(p_algorithm binary_integer := 0) return varchar2;

	function ps
	(
		tpl  in varchar2 character set any_cs,
		subs varchar2 character set any_cs,
		ch   char := ':'
	) return varchar2 character set tpl%charset;

	function ps
	(
		pat  varchar2 character set any_cs,
		vals st,
		ch   char := ':'
	) return varchar2 character set pat%charset;

	-- like c's printf, use ~ for replacement by default
	function pf
	(
		pat  varchar2 character set any_cs,
		subs st,
		ch   char := '~'
	) return varchar2 character set pat%charset;

	function tf
	(
		cond boolean,
		t    varchar2 character set any_cs,
		f    varchar2 character set t%charset := ''
	) return varchar2 character set t%charset;

	function nnpre
	(
		pre varchar2 character set any_cs,
		str varchar2 character set any_cs
	) return varchar2 character set str%charset;

	function nvl2
	(
		cond varchar2 character set any_cs,
		nn   varchar2 character set cond%charset,
		n    varchar2 character set cond%charset := ''
	) return varchar2 character set cond%charset;

	procedure split
	(
		stv in out nocopy st,
		p   varchar2,
		sep varchar2 := ',',
		trm boolean := true
	);

	function join
	(
		stv in out nocopy st,
		sep varchar2 := ','
	) return varchar2;
	function joinc
	(
		stv st,
		sep varchar2 := ','
	) return varchar2;

	procedure gen_seq_list
	(
		amount pls_integer,
		ntv    in out nocopy nt
	);

	procedure loop_init;
	function loop_first return boolean;
	procedure loop_count;
	function loop_count return pls_integer;
	function loop_empty return boolean;

end k_type_tool;
/
