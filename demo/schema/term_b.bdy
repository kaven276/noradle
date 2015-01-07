create or replace package body term_b is

	procedure setting_form is
	begin
		begin
			rc.set_term_info(r.msid);
		exception
			when no_data_found then
				null;
		end;
		p.h;
		src_b.link_proc;
		src_b.link_proc('term_b.setting_save');
		src_b.link_proc('rc.set_term_info');
		p.br;
		p.p('please login first to get a session');
		p.p('result cache ' || t.tf(rcpv.term_hit, 'hit', 'miss'));
		p.p('rcpv.term_row.msid=' || rcpv.term_row.msid);
		p.p('rcpv.term_row.ora_rowscn=' || rcpv.term_ver);
		p.p('r.getc(''s$term_ver'')=' || r.getc('s$term_ver'));
		p.p('rcpv.term_row.bgcolor=' || rcpv.term_row.bgcolor);
		p.p('rcpv.term_row.fgcolor=' || rcpv.term_row.fgcolor);
		p.a('refresh', 'setting_form');
		if rcpv.term_row.bgcolor is not null then
			p.style_open;
			p.line('body{background-color:' || rcpv.term_row.bgcolor || '}');
			p.line('body{color:' || rcpv.term_row.fgcolor || '}');
			p.style_close;
		end if;
		p.p('The pattern in package RC will use result cache function to get versioned rowtype data,');
		p.p(' and set them in package variable and avoid requent reads on table.');
		p.p('This method will run well on both oracle 11.1 and 11.2, through they do differently for result cache dependency');
		p.form_open('f', 'setting_save', method => 'post');
		t.split(p.gv_texts, 'red,blue,green,silver,gray', ',');
		p.gv_values := p.gv_texts;
		p.select_single('bgcolor', rcpv.term_row.bgcolor, 'background-color');
		p.br;
		t.split(p.gv_texts, 'red,blue,green,silver,gray', ',');
		p.gv_values := p.gv_texts;
		p.select_single('fgcolor', rcpv.term_row.fgcolor, 'foreground-color');
		p.br;
		p.input_submit;
		p.form_close;
	end;

	procedure setting_save is
		v term_t%rowtype;
	begin
		h.allow_post;
		v.msid    := r.msid;
		v.bgcolor := r.getc('bgcolor');
		v.fgcolor := r.getc('fgcolor');
		update term_t a set row = v where a.msid = v.msid;
		if sql%rowcount = 0 then
			insert into term_t values v;
		end if;
		-- the commit is fatal required, so ora_rowscn can refrect new version value
		commit;
		select ora_rowscn into rcpv.term_ver from term_t a where a.msid = v.msid;
		r.setc('s$term_ver', rcpv.term_ver);
		h.go('setting_form');
	end;

end term_b;
/
