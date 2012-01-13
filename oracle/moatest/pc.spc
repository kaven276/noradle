create or replace package pc is

	function changed
	(
		p_namespace varchar2,
		p_cache_id  in out nocopy varchar2,
		p_this_id   varchar2
	) return boolean;

	procedure change
	(
		p_namespace varchar2,
		p_cache_id  varchar2
	);

end pc;
/

