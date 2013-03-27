create or replace package body cache is

	procedure set_public is
	begin
		pv.headers('c-privacy') := 'public';
	end;

	procedure set_private is
	begin
		pv.headers('c-privacy') := 'private';
	end;

	procedure no_cache is
	begin
		pv.headers('c-no-cache') := 'Y';
	end;

	procedure no_store is
	begin
		pv.headers('c-no-store') := 'Y';
	end;

	procedure no_transform is
	begin
		pv.headers('c-no-transform') := 'Y';
	end;

	procedure must_revalidate is
	begin
		pv.headers('c-must-revalidate') := 'Y';
	end;

	procedure proxy_revlidate is
	begin
		pv.headers('c-proxy-revalidate') := 'Y';
	end;

	procedure max_age(seconds natural) is
	begin
		pv.headers('c-max-age') := to_char(seconds);
	end;

	procedure s_maxage(seconds natural) is
	begin
		pv.headers('c-s-maxage') := to_char(seconds);
	end;

end cache;
/
