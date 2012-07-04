create or replace package k_ext_call is

	procedure init;

	procedure write(content in out nocopy raw);

	procedure line
	(
		str    varchar2 character set any_cs,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	);

	function send_request(proxy_id pls_integer) return pls_integer;

	procedure send_request(proxy_id pls_integer);

	function read_response
	(
		req_seq pls_integer,
		req_blb in out nocopy blob,
		timeout pls_integer := null
	) return boolean;

	function call_sync
	(
		proxy_id pls_integer,
		req_blb  blob,
		timeout  pls_integer := null
	) return boolean;

end k_ext_call;
/
