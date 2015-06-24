create or replace package tag is

	function w
	(
		text varchar2,
		tag  varchar2 := 'b'
	) return varchar2;
	function r
	(
		text varchar2,
		dyna varchar2
	) return varchar2;

	function b2c
	(
		value boolean,
		attr  varchar2
	) return varchar2;
	function checked(value boolean) return varchar2;
	function selected(value boolean) return varchar2;
	function readonly(value boolean) return varchar2;
	function disabled(value boolean) return varchar2;
	function defer(value boolean) return varchar2;
	function async(value boolean) return varchar2;

	function base
	(
		tag   varchar2,
		para  st := null,
		text  varchar2 character set any_cs,
		extra varchar2 := ''
	) return nvarchar2;

	procedure o
	(
		tag  varchar2,
		para st := st()
	);
	procedure c(tag varchar2);
	function t
	(
		text varchar2 character set any_cs,
		para st := null,
		cut  boolean := false
	) return varchar2;
	procedure t
	(
		text   varchar2 character set any_cs,
		para   st := null,
		indent boolean := true,
		cut    boolean := false
	);

	function p
	(
		tag   varchar2,
		inner varchar2 character set any_cs,
		para  st := null,
		cut   boolean := false
	) return nvarchar2;
	procedure p
	(
		tag   varchar2,
		inner varchar2 character set any_cs,
		para  st := null,
		cut   boolean := false
	);
	function s
	(
		tag  varchar2,
		para st := null,
		cut  boolean := false
	) return varchar2;
	procedure s
	(
		tag  varchar2,
		para st := null,
		cut  boolean := false
	);

	function a
	(
		tg   varchar2,
		text varchar2 character set any_cs,
		href varchar2,
		para st := null,
		cut  boolean := false
	) return nvarchar2;
	procedure a
	(
		tg   varchar2,
		text varchar2 character set any_cs,
		href varchar2,
		para st := null,
		cut  boolean := false
	);
	function v
	(
		tg    varchar2,
		value varchar2,
		para  st := null
	) return varchar2;
	procedure v
	(
		tg    varchar2,
		value varchar2,
		para  st := null
	);
	function i
	(
		tg   varchar2,
		src  varchar2,
		para st := null
	) return varchar2;
	procedure i
	(
		tg   varchar2,
		src  varchar2,
		para st := null
	);

	function e(text varchar2 character set any_cs) return varchar2;
	procedure j
	(
		tg   varchar2,
		src  varchar2,
		para st := null
	);
	procedure l
	(
		tg   varchar2,
		href varchar2,
		para st := null
	);

end tag;
/
