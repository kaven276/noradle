create or replace package k_gac is

	procedure set(ctx varchar2, attr varchar2, value varchar2);

	procedure rm(ctx varchar2, attr varchar2);

	procedure rm(ctx varchar2);

end k_gac;
/

