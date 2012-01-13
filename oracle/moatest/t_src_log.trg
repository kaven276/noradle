create or replace trigger t_src_log
  after create  on  database 
	
when (ora_dict_obj_type != 'PSP1' and ora_dict_obj_name!='T_SRC_LOG1' and  ora_dict_obj_name not like 'P$%' )
declare
	-- local variables here
	v      cmp_prog_version%rowtype;
	v_clob clob;
	v_len  pls_integer;
begin
	if ora_dict_obj_type not in ('PACKAGE', 'PACKAGE BODY', 'TRIGGER') then
		return;
	end if;
	v.object_schema := ora_dict_obj_owner;
	v.object_type   := ora_dict_obj_type;
	v.object_name   := ora_dict_obj_name;
	v.compile_scn   := dbms_flashback.get_system_change_number;
	v.compile_time  := sysdate;
	v.sid           := sys_context('USERENV', 'sid');
	select a.serial# into v.serial from v$session a where a.sid = v.sid;
	v.host   := sys_context('userenv', 'host');
	v.source := empty_clob;
	insert into cmp_prog_version a values v returning a.source into v.source;
	for i in (select a.text
							from dba_source a
						 where a.owner = v.object_schema
							 and a.type = v.object_type
							 and a.name = v.object_name
						 order by a.line asc) loop
		dbms_lob.append(v.source, to_clob(i.text));
	end loop;
	return;
	select b.source
		into v_clob
		from (select a.*
						from cmp_prog_version a
					 where a.object_schema = v.object_schema
						 and a.object_type = v.object_type
						 and a.object_name = v.object_name
					 order by a.compile_scn desc) b
	 where rownum <= 1;
	if dbms_lob.compare(v_clob, v.source) = 0 then
		v_len := dbms_lob.getlength(v_clob);
		dbms_lob.erase(v.source, v_len);
	end if;
	-- dbms_alert.signal('test', 'sdf');
exception
	when no_data_found then
		null;
end t_src_log;
/

