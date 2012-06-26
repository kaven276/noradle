create or replace package k_ext_call is

	procedure init;

	procedure write(content in out nocopy raw);

	procedure line
	(
		str    varchar2 character set any_cs,
		nl     varchar2 := chr(10),
		indent pls_integer := null
	);

	procedure send(proxy_id pls_integer);

end k_ext_call;
/
