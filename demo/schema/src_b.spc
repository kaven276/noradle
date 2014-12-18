create or replace package src_b is

	procedure pack;

	procedure proc;

	procedure link_pack(pack varchar2 := null);

	procedure link_proc(proc varchar2 := null);

end src_b;
/
