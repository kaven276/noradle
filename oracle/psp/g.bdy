create or replace package body g is

	procedure finish is
	begin
		commit;
		raise pv.ex_resp_done;
	end;

	procedure cancel is
	begin
		rollback;
		raise pv.ex_resp_done;
	end;

	procedure feedback(value boolean := true) is
	begin
		r.setc('f$feedback', t.tf(value, 'Y', 'N'));
	end;

	procedure interrupt(url varchar2) is
		v_sep char(1) := t.tf(instrb(url, '?') > 0, '&', '?');
	begin
		h.go(url || v_sep || 'action=' || utl_url.escape(r.url || '&$referer=' || utl_url.escape(r.referer, true), true));
	end;

	procedure alert_go
	(
		text varchar2,
		url  varchar2
	) is
	begin
		x.o('<html>');
		x.o('<head>');
		x.p('<script>', 'alert("' || text || '");');
		x.p('<script>', 'location.href="' || l(url) || '";');
		--x.p('<script>', 'location.assign("' || l(url) || '");');
		x.c('</head>');
		x.c('</html>');
	end;

	procedure alert_back
	(
		text      varchar2,
		back_step pls_integer := 1
	) is
	begin
		x.o('<html>');
		x.o('<head>');
		x.p('<script>', 'alert("' || text || '");');
		x.p('<script>', 'history.go(-' || back_step || ');');
		x.c('</head>');
		x.c('</html>');
	end;

end g;
/
