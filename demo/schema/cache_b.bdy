create or replace package body cache_b is

	procedure expires is
	begin
		h.expires(sysdate + 1);
		pc.h;
		src_b.link_proc;
		x.p('<p>', 'Now is at ' || t.dt2s(sysdate) || '.');
		x.p('<p>', 'This page will expire a whole day later.');
		x.p('<p>',
				'If your browser support expire cache model, when you click link to this page, the Now time will not change for the cached page.');
		x.p('<p>', 'Using expires will save network round trip, such improve proformance.');
		x.p('<p>', 'You can use special keys such as "F5", "Command-R" to force request to server for current version.');
	end;

	procedure last_modified is
	begin
		h.expires_now;
		h.last_modified(trunc(sysdate));
		select max(a.last_ddl_time) into tmp.dt from user_objects a;
		h.last_modified(tmp.dt);
		h.check_if_not_modified_since;
		--h.header_close; -- It's required to avoid executing the main code.
	
		pc.h;
		src_b.link_proc;
		x.p('<p>', 'When this page is accessed, It may return 304 not modified for the entire day until mid-night.');
		x.p('<p>',
				'But if you modified/compiled some of the schema objeccts, It will detect the change and return the current version');
		x.p('<p>',
				'The last-modified-time will be max of the 00:00 in the morning or last-ddl-time of the schema objects.');
		x.p('<p>',
				'You can call h.last_modified multiple times, then call h.header_close, ' || '
		the last-modified header will be set the lasted date value of them, ' ||
				'So if the page have many parts, you can call h.last_modified for each part''s last modified time.');
		x.t(' <br/>');
	
		for i in (select * from user_objects a where a.object_type != 'PACKAGE' order by a.last_ddl_time desc) loop
			x.p('<p>', t.dt2s(i.last_ddl_time) || ' > ' || i.object_name);
		end loop;
	end;

	procedure etag_md5 is
		--v_charset varchar2(30) := nls_charset_name(nls_charset_id('CHAR_CS'));
	begin
		h.etag_md5_on;
		pc.h;
		src_b.link_proc;
		x.p('<p>', to_char(nls_charset_id('CHAR_CS')));
		x.p('<h3>', 'There are all the schema object name list.');
		x.p('<h4>', 'If all of them are not changed, it will return 304 not modified.');
		x.p('<h4>',
				'The page will still generating full page at oracle server side, ' ||
				'But response body is saved from network transfer if it is not changed, ' ||
				'Normally network transfer is the main factor for final response speed, ' ||
				'So using automatically computed md5 as the ETag http header value (h.etag_md5_on) on cachable page can improve perforance greatly.');
		for i in (select * from user_objects a where a.object_type != 'PACKAGE' order by a.last_ddl_time desc) loop
			x.p('<p>', t.dt2s(i.last_ddl_time) || ' > ' || i.object_name);
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
		pc.h;
		src_b.link_proc;
	
		x.p('<p>',
				'The user table report will update at start point of every hour. If you update the user table, the change can only see at the next hour.');
		x.p('<p>', 'You can click ' || x.a('<a>', 'here', 'user_b.register') || ' to change user table and do test.');
		x.p('<p>', 'Here we use flashback query to show the example.');
		x.p('<p>', 'If you report snapshot date in history, you can use last-modified method to lever the cache.');
	
		x.p('<h3>', 'There is the existing user list.');
		x.o('<table rules=all,cellpadding=4>');
		x.p(' <thead>', x.p('<tr>', m.w('<th>@</th>', 'USERNAME,PASSWORD,CREATE TIME')));
		x.o(' <tbody>');
		for i in (select * from user_t as of timestamp v_date) loop
			tmp.stv := st(i.name, i.pass, t.dt2s(i.ctime));
			x.p('<tr>', m.w('<td>', tmp.stv, '</td>'));
		end loop;
		x.c(' </tbody>');
		x.c('</table>');
	end;

end cache_b;
/
