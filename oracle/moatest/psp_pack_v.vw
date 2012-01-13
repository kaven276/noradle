create or replace view psp_pack_v as
select "SCHM","PACK","BRIEF","COMMENTS","CRT_CODER","RSP_CODER","DEV_STS" from psp_pack_t t where t.schm = sys_context('userenv', 'CURRENT_SCHEMA')
	with check option;

