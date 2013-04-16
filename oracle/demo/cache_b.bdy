create or replace package body cache_b is

	procedure expires is
	begin
		h.expires(sysdate + 1);
		p.h;
		src_b.link_proc;
		p.p('Now is at ' || t.dt2s(sysdate) || '.');
		p.p('This page will expire a whole day later.');
		p.p('If your browser support expire cache model, when you click link to this page, the Now time will not change for the cached page.');
		p.p('Using expires will save network round trip, such improve proformance.');
		p.p('You can use special keys such as "F5", "Command-R" to force request to server for current version.');
	end;

	procedure last_modified is
	begin
		h.expires_now;
		h.last_modified(trunc(sysdate));
		select max(a.last_ddl_time) into tmp.dt from user_objects a;
		h.last_modified(tmp.dt);
		h.check_if_not_modified_since;
		--h.header_close; -- It's required to avoid executing the main code.
	
		p.h;
		src_b.link_proc;
		p.p('When this page is accessed, It may return 304 not modified for the entire day until mid-night.');
		p.p('But if you modified/compiled some of the schema objeccts, It will detect the change and return the current version');
		p.p('The last-modified-time will be max of the 00:00 in the morning or last-ddl-time of the schema objects.');
		p.p('You can call h.last_modified multiple times, then call h.header_close, ' || '
		the last-modified header will be set the lasted date value of them, ' ||
				'So if the page have many parts, you can call h.last_modified for each part''s last modified time.');
		p.br;
	
		for i in (select * from user_objects a where a.object_type != 'PACKAGE' order by a.last_ddl_time desc) loop
			p.p(t.dt2s(i.last_ddl_time) || ' > ' || i.object_name);
		end loop;
	end;

	procedure etag_md5 is
	begin
		h.etag_md5_on;
		p.h;
		src_b.link_proc;
		p.hn(3, 'There are all the schema object name list.');
		p.hn(4, 'If all of them are not changed, it will return 304 not modified.');
		p.hn(4,
				 'The page will still generating full page at oracle server side, ' ||
				 'But response body is saved from network transfer if it is not changed, ' ||
				 'Normally network transfer is the main factor for final response speed, ' ||
				 'So using automatically computed md5 as the ETag http header value (h.etag_md5_on) on cachable page can improve perforance greatly.');
		for i in (select * from user_objects a where a.object_type != 'PACKAGE' order by a.last_ddl_time desc) loop
			p.p(t.dt2s(i.last_ddl_time) || ' > ' || i.object_name);
		end loop;
	end;

	procedure etag_manual is
	begin
		h.etag('md5value');
	end;

	procedure report_by_hour is
		v_date date := trunc(sysdate, 'hh');
	begin
		h.last_modified(v_date);
		h.expires_now;
		h.header_close;
		p.h;
		src_b.link_proc;
	
		p.p('The user table report will update at start point of every hour. If you update the user table, the change can only see at the next hour.');
		p.p('You can click ' || p.a('here', 'user_b.register') || ' to change user table and do test.');
		p.p('Here we use flashback query to show the example.');
		p.p('If you report snapshot date in history, you can use last-modified method to lever the cache.');
	
		p.hn(3, 'There is the existing user list.');
		p.table_open('all', cellpadding => 4);
		p.thead_open;
		p.tr(p.ths('USERNAME,PASSWORD,CREATE TIME'));
		p.thead_close;
		for i in (select * from user_t as of timestamp v_date) loop
			p.tr(p.tds(st(i.name, i.pass, t.dt2s(i.ctime))));
		end loop;
		p.table_close;
	end;

end cache_b;
/
