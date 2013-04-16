create or replace package body error_b is

	procedure execute_with_error is
		procedure error_root is
		begin
			if mod(to_char(sysdate, 'ss'), 2) = 1 then
				raise_application_error(-20000, 'some exception');
			end if;
		end;
	begin
		error_root;
		p.h;
		src_b.link_proc;
		p.p('This page will raise exception at odd seconds.');
		p.p('But you have luck, all is ok.');
	end;

	procedure on_developing is
	begin
		h.sts_501_not_implemented;
		src_b.link_proc;
		h.line('<br/>This page is under development, please wait for it''s release.');
	end;

	procedure check_right is
	begin
		if mod(to_char(sysdate, 'ss'), 2) = 1 then
			h.sts_403_forbidden;
			p.h;
			src_b.link_proc;
			p.p('You are not allowed to access this page at odd seconds');
		else
			p.h;
			src_b.link_proc;
			p.p('You are allowed to access this page at even seconds only');
		end if;
	end;

	procedure maybe_no_data is
		v_pack varchar2(30) := upper(r.getc('pack', ''));
	begin
		select count(*)
			into tmp.cnt
			from user_objects a
		 where a.object_name = v_pack
			 and a.object_type = 'PACKAGE BODY';
		if tmp.cnt = 0 then
			h.sts_404_not_found;
			p.h;
			src_b.link_proc;
			p.p('There is no package named ' || v_pack);
			p.form_open;
			p.select_open('pack');
			p.select_option('NONE', 'NONE');
			for i in (select a.object_name into tmp.cnt from user_objects a where a.object_type = 'PACKAGE BODY') loop
				p.select_option(i.object_name, i.object_name);
			end loop;
			p.select_close;
			p.input_submit;
			p.form_close;
		else
			src_b.link_proc;
			p.hn(3, 'Pakcage ' || v_pack || ' has the following sub procedures');
			for i in (select a.procedure_name from user_procedures a where a.object_name = v_pack) loop
				p.p(i.procedure_name);
			end loop;
		end if;
	end;

	procedure call_external is
	begin
		if mod(to_char(sysdate, 'ss'), 2) = 1 then
			h.sts_503_service_unavailable;
			p.h;
			src_b.link_proc;
			p.p('This page call a external service that''s unavailable for now.');
		else
			p.h;
			src_b.link_proc;
			p.p('Lucky, Call external service out of DB successfully.');
		end if;
		p.p('If plsql call a out-of-db service, such as through db-link, external procedure, http,' ||
				' that service may be unavailable, so return 503 service unavailable is ok.');
	end;

end error_b;
/
