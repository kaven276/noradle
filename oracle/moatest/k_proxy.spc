create or replace package k_proxy is

	-- Refactored procedure send_command
	function send_command
	(
		p_src_url varchar2,
		p_js_url  varchar2,
		p_cb_url  varchar2 := null
	) return number;

end k_proxy;
/

