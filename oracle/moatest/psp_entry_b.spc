create or replace package psp_entry_b authid current_user is

	procedure pack_list;

	procedure proc_list(p_pack varchar2 := r.getc('p_pack', null));

end psp_entry_b;
/

