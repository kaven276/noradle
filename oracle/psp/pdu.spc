create or replace package pdu is

	type name_value_t is table of varchar2(4000) index by varchar2(30);

	procedure start_parse(req_seq pls_integer);

	function get_binary_integer return binary_integer;

	function get_binary_float return binary_float;

	function get_binary_double return binary_double;

	procedure get_raw
	(
		tar   in out nocopy raw,
		bytes pls_integer
	);

	function get_varchar2(bytes pls_integer) return varchar2;

	function get_nvarchar2(bytes pls_integer) return nvarchar2;

	function get_char_line return varchar2;

	function get_nchar_line return nvarchar2;

	procedure get_name_value(hash in out nocopy name_value_t);

	procedure clear;

end pdu;
/
