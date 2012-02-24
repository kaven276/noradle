create or replace package body psp_dad_adm_b is

	procedure dad_list is
		v_dad_names dbms_epg.varchar2_table;
		v_paths     dbms_epg.varchar2_table;
		v_path      varchar2(100);
		v_user      varchar2(30);
		v_str       varchar2(100) := q'sss';
	begin
		dbms_epg.get_dad_list(v_dad_names);
		p.html_head(links => st('u:vml_table.css'));
		p.line('<table><tr><td>');
		p.tag_open('v:roundrect', ac => st('id=rr;arcsize=0.05;fillcolor=#F5DEB3;'));
		p.table_open(rules => 'all', cellpadding => '8', ac => st('class=rr;'));
		p.caption(p.b('所有 dad 清单') || p.a('添加', 'u:dad_add', '_blank'));
		p.thead_open;
		p.ths('dadname,path,dbuser,do-auth,do-deauth');
		p.thead_close;
		p.tbody_open;
		for i in 1 .. v_dad_names.count loop
			if v_dad_names(i) not in ('psp', 'APEX') then
				dbms_epg.get_all_dad_mappings(v_dad_names(i), v_paths);
				v_user := dbms_epg.get_dad_attribute(v_dad_names(i), 'database-username');
				p.tr_open;
				v_path := replace(v_paths(1), '/*', '');
				p.td(p.a(v_dad_names(i), v_path, '_blank'));
				p.td(v_paths(1));
				p.td(v_user);
				p.td(p.a('授权', v_path || '/psp_auth_dad_c.auth', '_blank'));
				p.td(p.a('回收', v_path || '/psp_auth_dad_c.deauth', '_blank'));
				p.tr_close;
			end if;
		end loop;
		p.tbody_close;
		p.table_close;
		p.tag_close('v:roundrect');
		p.line('</td></tr></table>');
	end;

	procedure dad_add is
		v_psp_time date;
	begin
		p.html_head(title => '添加dad');
		p.form_open;
		select u.created into v_psp_time from dba_users u where u.username = 'PSP';
		select u.username, u.username bulk collect
			into p.gv_texts, p.gv_values
			from dba_users u
		 where u.created > v_psp_time
		 order by u.created desc;
		p.select_single;
		p.form_close;
	end;

end psp_dad_adm_b;
/

