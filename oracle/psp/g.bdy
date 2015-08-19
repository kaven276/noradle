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

end g;
/
