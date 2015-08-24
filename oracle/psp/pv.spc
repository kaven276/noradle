create or replace package pv is

	/* all private process/call level state should be here */

	-- process level
	entry      varchar2(60);
	cfg_id     varchar2(30); -- filled with current server_control_t id
	in_seq     pls_integer; -- slot in in the current configuration
	cslot_id   pls_integer;
	production boolean;
	c          utl_tcp.connection; -- TCP/IP connection to the Web server

	-- call level
	protocol varchar2(30); -- call protocol (gateway.listen to branch req read and init)
	hp_flag  boolean;
	hp_label varchar2(2047); -- set to dbmshp run comment

	$if k_ccflag.use_time_stats $then
	elpt number(10); -- elapsed-time
	cput number(10); -- cpu-time
	$end

	elpl number(10); -- elapsed-long, last record time, used for detecting long execution
	wlen pls_integer; -- dummy pls_integer holder

	-- response header control/state
	header_writen boolean; -- prevent dup header write when flush
	bom           varchar2(10);
	allow         varchar2(100);
	status_code   number(3);
	mime_type     varchar2(100);
	charset       varchar2(30); -- http output charset
	charset_ora   varchar2(30); -- http output charset name in db
	cs_req        varchar2(30); -- req param's cs, default to output cs
	etag_md5      boolean; -- if autogen etag and 304 response, null for auto
	max_lmt       date; -- used to autogen last-modified and 304 response
	max_scn       number; -- used to autogen last-scn ETag and 304 response

	-- all of request/response params, headers, cookies and their types
	type vc_arr is table of varchar2(32767) index by binary_integer; -- r.na,r.va
	type str_arr is table of varchar2(1000) index by varchar2(100);
	headers str_arr; -- output headers
	cookies str_arr; -- output cookies

	mp_headers str_arr; -- msg pipe headers

	-- read line from rb.clob_entity(request entity body)
	rl_pos number(10); -- read line current position
	rl_end boolean; -- if read line is end
	rl_nlc varchar2(2); -- read line break characters

	-- all of response entity related
	type pg_parts_arr is table of nvarchar2(32767) index by binary_integer;
	type ph_parts_arr is table of varchar2(32767) index by binary_integer;
	pg_buf   nvarchar2(8000); -- hold current/lastest write buffer
	pg_parts pg_parts_arr; -- hold all written parts
	pg_index pls_integer; -- written parts index high watermark
	pg_idxsp pls_integer; -- index save point
	pg_len   pls_integer; -- written parts's total lengthb
	pg_lensp pls_integer; -- pg_len save point
	pg_cssno pls_integer; -- where css should insert into pg_parts
	pg_svptr pls_integer; -- output savepoint, used for h.save_pointer,h.appended
	pg_css   nvarchar2(32767); -- hold component css text
	pg_nchar boolean;
	pg_conv  boolean;
	ph_buf   varchar2(8000); -- hold current/lastest write buffer
	ph_parts ph_parts_arr; -- hold all written parts

	-- all output variation control state
	firstpg boolean; -- if clear and rewrite page, following PVs keep when re-init
	nlbr    varchar2(2); -- set by h.set_line_break, used by output.line after all
	nlbr0   varchar2(2);

	-- stream/flush output flow control related
	-- use_stream will inited to true
	-- p.comp_css_link,h.content_encoding_try_zip,g.feedback cause it to be false
	-- flush will be ignored when use_stream=false
	use_stream boolean; -- null:cache all;false:force not flush;true:force flush
	flushed    boolean; -- if any flush actually occurred
	msg_stream boolean;
	accum_cnt  pls_integer;

	bsid varchar2(100); -- client session browser sid
	msid varchar2(100); -- client session machine(terminal) sid

	-- constants
	tz_offset     constant number(2) := to_number(substrb(standard.tz_offset(sessiontimezone), 2, 2));
	base64_cookie constant varchar2(26) := 'abcdefghijklmnopqrstuvwxyz';
	base64_gac    constant varchar2(26) := '!"#$%&()*,-:;<>?@[]^_`{|}~';
	gac_dtfmt     constant varchar2(14) := 'yyyymmddhh24mi';
	cs_char       constant varchar2(30) := nls_charset_name(nls_charset_id('CHAR_CS'));
	cs_nchar      constant varchar2(30) := nls_charset_name(nls_charset_id('NCHAR_CS'));
	pspuser       constant varchar2(30) := sys_context('userenv', 'current_schema');

	cid varchar2(64);

	ex_continue              exception;
	ex_quit                  exception;
	ex_dummy                 exception;
	ex_resp_done             exception;
	ex_no_prog               exception;
	ex_no_subprog            exception; -- user.table.column, table.column 
	ex_no_filter             exception;
	ex_package_state_invalid exception;
	ex_invalid_proc          exception;

	pragma exception_init(ex_continue, -20995);
	pragma exception_init(ex_quit, -20996);
	pragma exception_init(ex_dummy, -20997);
	pragma exception_init(ex_resp_done, -20998);
	pragma exception_init(ex_no_prog, -6576);
	pragma exception_init(ex_no_subprog, -01747);
	pragma exception_init(ex_no_filter, -06550); -- Usually a PL/SQL compilation error.
	pragma exception_init(ex_package_state_invalid, -04061); -- 04061
	pragma exception_init(ex_invalid_proc, -6576);

end pv;
/
