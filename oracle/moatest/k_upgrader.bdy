create or replace package body k_upgrader is

	procedure reorg_static is
	begin
		for i in (select a.any_path, path(1) dad from resource_view a where under_path(a.res, 1, '/psp.web/static/', 1) = 1) loop
			dbms_output.put_line(i.dad || ' : ');
			for j in (select path(1) f, a.any_path p
									from resource_view a
								 where under_path(a.res, 1, '/psp.web/static/' || i.dad || '/common/', 1) = 1) loop
				dbms_output.put_line(i.dad || ' , ' || j.p);
				dbms_xdb.renameresource(j.p, '/psp.web/static/' || i.dad || '/', j.f);
			end loop;
			begin
				dbms_xdb.deleteresource('/psp.web/static/' || i.dad || '/common/');
			exception
				when others then
					null;
			end;
		end loop;
	end;

end k_upgrader;
/

