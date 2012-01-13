create or replace view psp_proc_v as
select "SCHM","PACK","PROC","BRIEF","COMMENTS" from psp_proc_t t where t.schm = sys_context('userenv', 'CURRENT_SCHEMA')
	with check option;

