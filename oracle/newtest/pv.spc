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

	type str_arr is table of varchar2(1000) index by varchar2(100);
	headers str_arr;
	cookies str_arr;

	entity blob;

	csslink     boolean;
	csstext     blob;
	css_len     pls_integer;
	css_ins     pls_integer;
	css_hld_pos pls_integer;
	css_hld_len pls_integer;

end pv;
/
