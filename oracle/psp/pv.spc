create or replace package pv is

	cur_cfg_id varchar2(30);
	seq_in_id  pls_integer;
	type vc_arr is table of varchar2(32000) index by binary_integer;
	tz_offset constant number(2) := 8;

	c         utl_tcp.connection; -- TCP/IP connection to the Web server
	ct_marker varchar2(30);
	protocol  varchar2(30);

	schema varchar2(30);
	prog   varchar2(30);

	elpt number(10); -- elapsed-time
	cput number(10); -- cpu-time

	elpl number(10);
	cpul number(10);

	write_buff_size pls_integer := 8132; -- will be auto set to lob chunk size, maxium to 32767

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

	nlbr   varchar2(2);

	svr_request_count number(9);
	svr_start_time    date;
	-- all of response entity related
	type pg_parts_arr is table of nvarchar2(32767) index by binary_integer;
	pg_buf   nvarchar2(32767); -- hold current/lastest write buffer
	pg_parts pg_parts_arr; -- hold all written parts
	pg_index pls_integer; -- written parts index high watermark
	pg_len   pls_integer; -- written parts's total lengthb
	pg_cssno pls_integer; -- where css should insert into pg_parts
	pg_css   nvarchar2(32767); -- hold component css text

	firstpg  boolean; -- if clear and rewrite page, following PVs keep when re-init
	feedback boolean; -- manually say(g.feedback) to use feedback mechanism
	csslink  boolean; -- say to use component css; true:link, false:embed
	-- stream/flush related
	-- use_stream will inited to true
	-- p.comp_css_link,h.content_encoding_try_zip,g.feedback cause it to be false
	-- flush will be ignored when use_stream=false
	use_stream boolean; -- 
	flushed    boolean; -- if any flush actually occurred
	end_marker varchar2(100) := 'EOF'; -- for streamed/flushed output, append it to tell nodejs the end of response
	msg_stream boolean;

	base64_cookie varchar2(26) := 'abcdefghijklmnopqrstuvwxyz';
	base64_gac    varchar2(26) := '!"#$%&()*,-:;<>?@[]^_`{|}~';
	gac_dtfmt constant varchar2(14) := 'yyyymmddhh24mi';
	ls_gid varchar2(99);
	ls_uid varchar2(99);
	ls_lgt date;
	ls_lat date;

	cs_utf8  varchar2(30) := utl_i18n.map_charset('utf-8', 0, 1);
	cs_char  varchar2(30) := nls_charset_name(nls_charset_id('CHAR_CS'));
	cs_nchar varchar2(30) := nls_charset_name(nls_charset_id('NCHAR_CS'));
	cs_req   varchar2(30);

	bsid varchar2(30);
	msid varchar2(30);
	ctx  varchar2(30); -- current ctx for k_sess to access

	ex_continue exception;
	ex_quit exception;
	ex_dummy exception;
	ex_resp_done exception;
	ex_fltr_done exception;
	ex_no_prog exception;
	ex_no_subprog exception; -- user.table.column, table.column 
	ex_no_filter exception;
	ex_package_state_invalid exception;
	ex_invalid_proc exception;

	pragma exception_init(ex_continue, -20995);
	pragma exception_init(ex_quit, -20996);
	pragma exception_init(ex_dummy, -20997);
	pragma exception_init(ex_resp_done, -20998);
	pragma exception_init(ex_fltr_done, -20999);
	pragma exception_init(ex_no_prog, -6576);
	pragma exception_init(ex_no_subprog, -01747);
	pragma exception_init(ex_no_filter, -06550); -- Usually a PL/SQL compilation error.
	pragma exception_init(ex_package_state_invalid, -04061); -- 04061
	pragma exception_init(ex_invalid_proc, -6576);

	pspuser varchar2(30);

end pv;
/
