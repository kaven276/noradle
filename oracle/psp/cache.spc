create or replace package cache is

	procedure set_public;

	procedure set_private;

	procedure no_cache;

	procedure no_store;

	procedure no_transform;

	procedure must_revalidate;

	procedure proxy_revlidate;

	procedure max_age(seconds natural);

	procedure s_maxage(seconds natural);

end cache;
/
