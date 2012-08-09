create or replace package body k_gac is

	gc_fmt constant varchar2(20) := 'yyyymmddhh24miss';

	procedure set
	(
		ctx   varchar2,
		attr  varchar2,
		value varchar2
	) is
	begin
		dbms_session.set_context(ctx, attr, value);
	end;

	procedure rm
	(
		ctx  varchar2,
		attr varchar2
	) is
	begin
		dbms_session.clear_context(ctx, attribute => attr);
	end;

	procedure rm(ctx varchar2) is
	begin
		dbms_session.clear_all_context(ctx);
	end;

	procedure gset
	(
		ctx   varchar2,
		attr  varchar2,
		value varchar2
	) is
	begin
		dbms_session.set_context(ctx, attr, value, client_id => sys_context('user', 'client_identifier'));
	end;

	procedure gsetn
	(
		ctx   varchar2,
		attr  varchar2,
		value number
	) is
	begin
		dbms_session.set_context(ctx, attr, to_char(value), client_id => sys_context('user', 'client_identifier'));
	end;

	procedure gsetd
	(
		ctx   varchar2,
		attr  varchar2,
		value date
	) is
	begin
		dbms_session.set_context(ctx, attr, to_char(value, gc_fmt), client_id => sys_context('user', 'client_identifier'));
	end;

	procedure grm
	(
		ctx  varchar2,
		attr varchar2
	) is
	begin
		dbms_session.clear_context(ctx, attribute => attr, client_id => sys_context('user', 'client_identifier'));
	end;

	procedure grm(ctx varchar2) is
	begin
		dbms_session.clear_context(ctx, client_id => sys_context('user', 'client_identifier'));
	end;

	function get
	(
		ctx  varchar2,
		attr varchar2
	) return varchar2 is
	begin
		return sys_context(ctx, attr);
	end;

	function getn
	(
		ctx  varchar2,
		attr varchar2
	) return number is
	begin
		return to_number(sys_context(ctx, attr));
	end;

	function getd
	(
		ctx  varchar2,
		attr varchar2
	) return date is
	begin
		return to_date(sys_context(ctx, attr), gc_fmt);
	end;

end k_gac;
/
