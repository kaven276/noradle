create or replace package body k_gac is

	procedure set(ctx varchar2, attr varchar2, value varchar2) is
	begin
		dbms_session.set_context(ctx, attr, value);
	end;

	procedure rm(ctx varchar2, attr varchar2) is
	begin
		dbms_session.clear_context(ctx, attribute => attr);
	end;

	procedure rm(ctx varchar2) is
	begin
		dbms_session.clear_all_context(ctx);
	end;

end k_gac;
/

