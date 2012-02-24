create or replace package body psp_prog_b is

	-- private
	procedure set_dialog_size
	(
		p_width  varchar2,
		p_height varchar2
	) is
	begin
		p.script_open;
		p.line(p.ps('window.dialogWidth=":1";', st(p_width)));
		p.line(p.ps('window.dialogHeight=":1";', st(p_height)));
		p.script_close;
	end;

	procedure comments_pack(p_pack varchar2) is
		v psp_pack_v%rowtype;
	begin
		begin
			select t.* into v from psp_pack_v t where t.pack = p_pack;
		exception
			when no_data_found then
				null;
		end;
		p.doc_type;
		p.html_open;
		p.head_open;
		p.base;
		set_dialog_size('700px', '360px');
		p.link('u:comments_prog.css');
		p.script('u:comments_prog.js', ac => st('defer=true;'));
		p.head_close;
		p.body_open;

		p.form_open('f_comment', 'psp_prog_c.comments_pack', method => 'post');
		p.input_hidden('p_pack', p_pack);
		p.table_open(cellpadding => 5, rules => 'all');
		p.caption(p_pack);
		p.tbody_open;
		p.tr_open;
		p.th(p.span('简要说明'));
		p.td(p.input_text('p_brief', v.brief, sizep => 60));
		p.tr_close;
		p.tr_open;
		p.th(p.span('详细说明'));
		p.td(p.textarea('p_comments', nvl(v.comments, '[add detailed comments here]'), cols => 60,
										rows => 10));
		p.tr_close;
		p.tbody_close;
		p.tfoot_open;
		p.tr_open;
		p.th(p.input_submit(n, '提交'), colspan => 2);
		p.tr_close;
		p.tfoot_close;
		p.table_close;
		p.form_close;
	end;

	procedure comments_proc
	(
		p_pack varchar2,
		p_proc varchar2
	) is
		v psp_proc_v%rowtype;
	begin
		begin
			select t.*
				into v
				from psp_proc_v t
			 where t.pack = p_pack
				 and t.proc = p_proc;
		exception
			when no_data_found then
				null;
		end;
		p.doc_type;
		p.html_open;
		p.head_open;
		p.base;
		set_dialog_size('700px', '360px');
		p.link('u:comments_prog.css');
		p.script('u:comments_prog.js', ac => st('defer=true;'));
		p.head_close;
		p.body_open;

		p.form_open(n, 'psp_prog_c.comments_proc', method => 'post');
		p.input_hidden('p_pack', p_pack);
		p.input_hidden('p_proc', p_proc);
		p.table_open(cellpadding => 5, rules => 'all');
		p.caption(p_pack);
		p.tbody_open;
		p.tr_open;
		p.th(p.span('简要说明'));
		p.td(p.input_text('p_brief', v.brief, sizep => 60));
		p.tr_close;
		p.tr_open;
		p.th(p.span('详细说明'));
		p.td(p.textarea('p_comments', nvl(v.comments, '[add detailed comments here]'), cols => 60,
										rows => 10));
		p.tr_close;
		p.tbody_close;
		p.tfoot_open;
		p.tr_open;
		p.th(p.input_submit(n, '提交'), colspan => 2);
		p.tr_close;
		p.tfoot_close;
		p.table_close;
		p.form_close;
	end;

	procedure export is
		v_xml xmltype;
	begin
		select xmlelement("prog_comments", xmlattributes('DEMO' as "schema"),
											xmlagg(xmlelement("pack", xmlattributes(t.pack as "name"),
																				 xmlforest(t.brief, t.comments),
																				 (select xmlelement("procs",
																														 xmlagg(xmlelement("proc",
																																								xmlattributes(s.proc as
																																															 "name"),
																																								xmlforest(s.brief,
																																													 s.comments))))
																						 from psp_proc_v s
																						where s.pack = t.pack))))
			into v_xml
			from psp_pack_v t;
		k_http.set_content_type(p_content_type => 'text/xml');
		p.http_header_close;
		p.prn(v_xml.getclobval());
	end;

end psp_prog_b;
/

