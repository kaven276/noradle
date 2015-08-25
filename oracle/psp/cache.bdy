create or replace package body cache is

	procedure set_public is
	begin
		pv.caches('public') := 'Y';
	end;

	procedure set_private is
	begin
		pv.caches('private') := 'Y';
	end;

	procedure no_cache is
	begin
		pv.caches('no-cache') := 'Y';
	end;

	procedure no_store is
	begin
		pv.caches('no-store') := 'Y';
	end;

	procedure no_transform is
	begin
		pv.caches('no-transform') := 'Y';
	end;

	procedure must_revalidate is
	begin
		pv.caches('must-revalidate') := 'Y';
	end;

	procedure proxy_revlidate is
	begin
		pv.caches('proxy-revalidate') := 'Y';
	end;

	procedure max_age(seconds natural) is
	begin
		pv.caches('max-age') := to_char(seconds);
	end;

	procedure s_maxage(seconds natural) is
	begin
		pv.caches('s-maxage') := to_char(seconds);
	end;

end cache;
/
