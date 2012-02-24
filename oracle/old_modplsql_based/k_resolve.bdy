create or replace package body k_resolve is

	procedure resolve_prog
	(
		p_name   varchar2,
		p_schema out varchar2,
		p_pack   out varchar2,
		p_proc   out varchar2
	) is
		v_dblink        varchar2(30);
		v_part1_type    varchar2(30);
		v_object_number integer;
	begin
		sys.dbms_utility.name_resolve(name => p_name, context => 1, schema => p_schema, part1 => p_pack,
																	part2 => p_proc, dblink => v_dblink, part1_type => v_part1_type,
																	object_number => v_object_number);
	end;

	procedure resolve_prog
	(
		p_name   varchar2,
		p_schema out varchar2,
		p_prog   out varchar2
	) is
		v_dblink        varchar2(30);
		v_pack          varchar2(30);
		v_proc          varchar2(30);
		v_part1_type    varchar2(30);
		v_object_number integer;
	begin
		sys.dbms_utility.name_resolve(name => p_name, context => 1, schema => p_schema, part1 => v_pack,
																	part2 => v_proc, dblink => v_dblink, part1_type => v_part1_type,
																	object_number => v_object_number);
		p_prog := v_pack || '.' || v_proc;
	end;

end k_resolve;
/

