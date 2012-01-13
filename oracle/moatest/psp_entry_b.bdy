create or replace package body psp_entry_b is

	gc_title constant varchar2(100) := '界面层 package 清单';

	function format_date(p_date date) return varchar2 is
	begin
		return to_char(p_date, 'YY-MM-DD HH24:MI:SS');
	end;

	procedure pack_list is
		v_title varchar2(100) := gc_title;
	begin
		if p.is_dhc then
			p.use_vml;
			p.h('u:vml_table.css,u:comment.js', v_title);
			-- p.script('u:vml_auto_size.js');
			-- p.script_open;
			--p.line('alert(window.screen.updateInterval);');
			--p.line('window.screen.updateInterval=500;');
			-- p.script_close;
		end if;

		p.line('<table id="outer"><tr><td id="outer_td">');

		--p.div_open(p_id => 'cont');
		p.tag_open('v:roundrect', st('arcsize=0.05;fillcolor=#F5DEB3;'));
		p.table_open(rules => 'all', cellpadding => '10', ac => st('class=rr;'));
		p.caption(p.el_open);
		p.b(v_title || ' ');
		p.a(p.img('u:img/gobut.gif', title => '查看最近变更的程序包'), 'u:proc_list');
		p.s := 'psp_prog_b.export';
		p.a(p.img('u:img/xml_upload2.gif', title => '导出程序说明', ac => st('id=exp;')), p.s, '_self');
		p.caption(p.el_close);
		p.thead_open;
		p.ths('程序名,据现在时长<br/>(日:时:分),最后修改时间,创建时间,状态,查看子程序,说明');
		p.thead_close;

		p.col(align => 'left');
		p.col(span => 5, align => 'center');
		p.tbody_open;
		for t in (select o.*,
										 decode(o.status, 'VALID', 'success.gif', 'fnderBLG.gif') sts_img,
										 (select count(*)
												from user_procedures p
											 where p.object_name = o.object_name
												 and p.procedure_name = 'D') d,
										 p.*
								from user_objects o
								left outer join psp_pack_v p on (o.object_name = p.pack)
							 where o.object_type = 'PACKAGE BODY'
								 and o.object_name like '%_B'
							 order by o.last_ddl_time desc) loop
			p.tr_open;
			if t.d = 0 then
				p.td(t.object_name);
			else
				p.td(p.a(t.object_name, lower(t.object_name) || '.d', '_self'));
			end if;
			p.td(substrb(numtodsinterval(sysdate - t.last_ddl_time, 'day'), 8, 9));
			p.td(format_date(t.last_ddl_time));
			p.td(format_date(t.created));
			p.td(p.img('u:img/' || t.sts_img, title => t.status));
			p.s := 'u:proc_list?p_pack=' || t.object_name;
			p.td(p.a(p.img('u:img/bulk_32x24.gif', ac => st('border=0;')), p.s, '_self'));
			p.td(t.brief, title => t.comments, ac => st('ondblclick=add_pack_comment(this);'));
			p.tr_close;
		end loop;
		p.tbody_close;
		p.table_close;
		p.tag_close('v:roundrect');
		p.line('</td></tr></table>');
		-- p.div_close;
	end;

	procedure proc_list(p_pack varchar2) is
		v_cnt   pls_integer;
		v_pack  varchar2(30);
	begin
		if p_pack is null then
			select t.object_name
				into v_pack
				from (select o.*
								from user_objects o
							 where o.object_type = 'PACKAGE'
								 and o.object_name like '%_B'
							 order by o.last_ddl_time desc) t
			 where rownum = 1;
		else
			v_pack := p_pack;
		end if;

		if p.is_dhc then
			p.use_vml;
			p.h('u:vml_table.css,u:comment.js');
		end if;

		p.br;
		p.line('<table id="outer"><tr><td>');
		p.tag_open('v:roundrect', st('id=rr;arcsize=0.05;fillcolor=#F5DEB3;'));
		p.table_open(cellpadding => '15', rules => 'all', ac => st('align=center;class=rr;'));
		select count(*)
			into v_cnt
			from user_procedures t
		 where t.object_name = upper(v_pack)
			 and t.procedure_name = 'D';
		if v_cnt = 0 then
			p.caption(v_pack);
		else
			p.caption(p.a(v_pack, v_pack || '.d', '_self'));
		end if;
		p.col;
		p.col;
		p.col(align => 'center');
		p.thead_open;
		p.ths('序号,子程序名,执行子程序,说明');
		p.thead_close;
		p.tbody_open;

		for t in (select *
								from (select distinct t.procedure_name, rownum rn
												from user_procedures t
											 where t.object_name = upper(v_pack)
												 and t.procedure_name != 'D'
												 and exists (select 1
																from user_arguments a
															 where a.package_name = t.object_name
																 and a.object_name = t.procedure_name
																 and a.data_type is null)
											 order by 1 asc) a
								left outer join psp_proc_v b on (a.procedure_name = b.proc and
																								b.pack = upper(v_pack))) loop
			p.tr_open;
			p.td(t.rn);
			p.td(t.procedure_name);
			p.s := lower(v_pack) || '.' || lower(t.procedure_name);
			p.td(p.a(p.img('u:img/Fndview1.gif', title => '执行', ac => st('border=0;')), p.s, '_self'));
			p.td(t.brief, st('ondblclick=add_proc_comment(this);'), t.comments);
			p.tr_close;
		end loop;
		p.tbody_close;
		p.tfoot_tr_td_open(4);
		p.a(p.img('u:img/homeicon.gif') || ' 回到' || gc_title, 'u:pack_list');
		p.tfoot_tr_td_close;
		p.table_close;
		p.tag_close('v:roundrect');
		p.line('</td></tr></table>');

	end;

end psp_entry_b;
/

