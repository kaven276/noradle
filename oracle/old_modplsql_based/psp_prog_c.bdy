create or replace package body psp_prog_c is

	-- Refactored procedure responde
	procedure responde(p_info varchar2) is
	begin
		p.doc_type;
		p.html_open;
		p.head_open;
		p.script_open;
		p.line('window.returnValue="' || p_info || '"');
		p.line('window.close();');
		p.script_close;
		p.head_close;
		p.html_close;
	end responde;

	procedure comments_pack
	(
		p_pack     varchar2,
		p_brief    varchar2,
		p_comments varchar2
	) is
	begin
		update psp_pack_v t
			 set t.schm     = sys_context('userenv', 'CURRENT_SCHEMA'),
					 t.brief    = p_brief,
					 t.comments = p_comments
		 where t.pack = p_pack;
		if sql%rowcount = 0 then
			insert into psp_pack_v
				(schm, pack, brief, comments)
			values
				(sys_context('userenv', 'CURRENT_SCHEMA'), p_pack, p_brief, p_comments);
		end if;
		responde(p.ps('成功更新 :1 的注释', st(p_pack)));
	end;

	procedure comments_proc
	(
		p_pack     varchar2,
		p_proc     varchar2,
		p_brief    varchar2,
		p_comments varchar2
	) is
	begin
		update psp_proc_v t
			 set t.schm     = sys_context('userenv', 'CURRENT_SCHEMA'),
					 t.brief    = p_brief,
					 t.comments = p_comments
		 where t.pack = p_pack
			 and t.proc = p_proc;
		if sql%rowcount = 0 then
			insert into psp_proc_v
				(schm, pack, proc, brief, comments)
			values
				(sys_context('userenv', 'CURRENT_SCHEMA'), p_pack, p_proc, p_brief, p_comments);
		end if;
		responde(p.ps('成功更新 :1.:2 的注释', st(p_pack, p_proc)));
	end;

end psp_prog_c;
/

