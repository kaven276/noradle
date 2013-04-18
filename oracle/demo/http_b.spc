create or replace package http_b is

	procedure gzip;

	procedure chunked_transfer;
	procedure long_job;

	procedure content_type;
	procedure content_css;
	procedure content_js;

	procedure refresh;

	procedure content_md5;

end http_b;
/
