create or replace package pv is

	tz_offset constant number(2) := 8;

	c utl_tcp.connection; -- TCP/IP connection to the Web server

	elpt number(10); -- elapsed-time
	cput number(10); -- cpu-time

	write_buff_size pls_integer := 8132; -- will be auto set to lob chunk size, maxium to 32767
	gzip_thres      pls_integer := 1000;

	use_stream      boolean;
	buffered_length number(8) := 0;
	end_marker      varchar2(100);

	header_writen boolean;
	allow_content boolean;
	allow         varchar2(100);

	status_code number(3);
	mime_type   varchar2(100);
	charset     varchar2(30);
	charset_ora varchar2(30);
	gzip        boolean;
	gzip_handle binary_integer;
	gzip_amount number(8);
	gzip_entity blob;
	content_md5 boolean;
	etag_md5    boolean;
	max_lmt     date;
	rl_pos      number(10);
	rl_end      boolean;
	rl_nlc      varchar2(2);

	type str_arr is table of varchar2(1000) index by varchar2(100);
	headers str_arr;
	cookies str_arr;

	entity blob;
	nlbr   varchar2(2);

	csslink     boolean;
	csstext     blob;
	css_len     pls_integer;
	css_ins     pls_integer;
	css_hld_pos pls_integer;
	css_hld_len pls_integer;

	svr_request_count number(9);
	svr_start_time    date;

	ex_resp_done exception;
	ex_fltr_done exception;
	ex_no_prog exception;
	ex_no_filter exception;
	ex_package_state_invalid exception;
	ex_invalid_proc exception;

	pragma exception_init(ex_resp_done, -20998);
	pragma exception_init(ex_fltr_done, -20999);
	pragma exception_init(ex_no_prog, -6576);
	pragma exception_init(ex_no_filter, -06550); -- Usually a PL/SQL compilation error.
	pragma exception_init(ex_package_state_invalid, -04061); -- 04061
	pragma exception_init(ex_invalid_proc, -6576);

end pv;
/
