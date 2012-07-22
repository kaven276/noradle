create or replace package pv is

	cur_cfg_id varchar2(30);
	type vc_arr is table of varchar2(32000) index by binary_integer;
	tz_offset constant number(2) := 8;

	c         utl_tcp.connection; -- TCP/IP connection to the Web server
	call_type pls_integer; -- to oracle call type 0 for psp 1 for direct all

	elpt number(10); -- elapsed-time
	cput number(10); -- cpu-time

	write_buff_size pls_integer := 8132; -- will be auto set to lob chunk size, maxium to 32767

	msg_stream      boolean;
	use_stream      boolean;
	flushed         boolean;
	chunk_max_size  pls_integer; -- when write over the size, auto flush buffer
	chunk_min_size  pls_integer; -- when write detect long idle, and buffer is more than the size, auto flush buffdf
	chunk_max_idle  interval day(0) to second(1); -- when write see last write time is more than
	last_flush      timestamp(1);
	buffered_length number(8) := 0;
	end_marker      varchar2(100);

	header_writen boolean;
	allow_content boolean;
	allow         varchar2(100);

	status_code number(3);
	mime_type   varchar2(100);
	charset     varchar2(30);
	charset_ora varchar2(30);
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

	feedback    boolean; -- force to use feedback mechanism
	csslink     boolean;
	csstext     blob;
	css_len     pls_integer;
	css_ins     pls_integer;
	css_hld_pos pls_integer;
	css_hld_len pls_integer;

	svr_request_count number(9);
	svr_start_time    date;

	base64_cookie varchar2(26) := 'abcdefghijklmnopqrstuvwxyz';
	base64_gac    varchar2(26) := '!"#$%&''()*,-./:;<>?@[\]{|}';
	gac_dtfmt constant varchar2(17) := 'yyyymmddhh24miss-';
	ls_gid varchar2(99);
	ls_uid varchar2(99);
	ls_lgt date;
	ls_lat date;

	cs_utf8  varchar2(30) := utl_i18n.map_charset('utf-8', 0, 1);
	cs_char  varchar2(30) := nls_charset_name(nls_charset_id('CHAR_CS'));
	cs_nchar varchar2(30) := nls_charset_name(nls_charset_id('NCHAR_CS'));
	cs_req   varchar2(30);

	ex_dummy exception;
	ex_resp_done exception;
	ex_fltr_done exception;
	ex_no_prog exception;
	ex_no_subprog exception; -- user.table.column, table.column 
	ex_no_filter exception;
	ex_package_state_invalid exception;
	ex_invalid_proc exception;

	pragma exception_init(ex_dummy, -20997);
	pragma exception_init(ex_resp_done, -20998);
	pragma exception_init(ex_fltr_done, -20999);
	pragma exception_init(ex_no_prog, -6576);
	pragma exception_init(ex_no_subprog, -01747);
	pragma exception_init(ex_no_filter, -06550); -- Usually a PL/SQL compilation error.
	pragma exception_init(ex_package_state_invalid, -04061); -- 04061
	pragma exception_init(ex_invalid_proc, -6576);

end pv;
/
