create or replace package body k_gac is

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

end k_gac;
/
