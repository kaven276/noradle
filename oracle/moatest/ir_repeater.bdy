create or replace package body ir_repeater is

	procedure trigger
	(
		p_tpl_schema   varchar2,
		p_trigger_name varchar2
	) is
		v dba_triggers%rowtype;
	begin
		for i in (select *
								from dad_t a
							 where a.irp_user = p_tpl_schema
								 and a.db_user != a.irp_user) loop
			select a.*
				into v
				from dba_triggers a
			 where a.owner = upper(p_tpl_schema)
				 and a.trigger_name = upper(p_trigger_name);
			dbms_output.put('create or replace trigger ' || i.db_user || '.' ||
													 replace(v.description, lower(v.table_name),
																	 i.db_user || '.' || lower(v.table_name)) || v.trigger_body);
			dbms_output.put_line('/');
		end loop;
	end;

end ir_repeater;
/

