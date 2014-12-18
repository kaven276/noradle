create or replace package body db_src_b is

	procedure example is
		cur sys_refcursor;
		v1  varchar2(50) := 'psp.web';
		v2  number := 123456;
		v3  date := date '1976-10-26';
	begin
		if r.call_type = 'HTTP' then
			h.content_type('text/resultsets', 'UTF-8');
			--h.content_type(h.rss, 'UTF-8');
			h.header('_convert', 'JSON');
		elsif r.call_type = 'DATA' then
			-- h.header('x-template', 'users');
			h.line('# You are not required to write " h.content_type(h.mime_text, ''UTF-8'') " if call by NodeJS.');
		end if;
	
		h.line('# a stardard psp.web result sets example page');
		h.line('# It can be used in browser or NodeJS');
		h.line('# You can use some standard parser or write your own ' ||
					 'parsers to convert the raw resultsets to javascript data object');
		h.line('# see PL/SQL source at ' || r.dir_full || '/src_b.proc/' || r.prog);
		h.write(chr(30) || chr(10));
	
		open cur for
			select a.object_name, a.subobject_name, a.object_type, a.created
				from user_objects a
			 where rownum <= r.getn('limit', 8);
		rs.print('test', cur);
	
		open cur for
			select v1 as name, v2 as val, v3 as ctime, r.getc('param1') p1, r.getc('param2') p2, r.getc('__parse') pnull
				from dual;
		rs.print('namevals', cur);
	end;

end db_src_b;
/
