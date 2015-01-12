create or replace package body term_b is

	procedure setting_form is
	begin
		begin
			rc.set_term_info(r.msid);
		exception
			when no_data_found then
				null;
		end;
		pc.h;
		src_b.link_proc;
		src_b.link_proc('term_b.setting_save');
		src_b.link_proc('rc.set_term_info');
		x.t('<br/>');
		x.p('<p>', 'please login first to get a session');
		x.p('<p>', 'result cache ' || t.tf(rcpv.term_hit, 'hit', 'miss'));
		x.p('<p>', 'rcpv.term_row.msid=' || rcpv.term_row.msid);
		x.p('<p>', 'rcpv.term_row.ora_rowscn=' || rcpv.term_ver);
		x.p('<p>', 'r.getc(''s$term_ver'')=' || r.getc('s$term_ver'));
		x.p('<p>', 'rcpv.term_row.bgcolor=' || rcpv.term_row.bgcolor);
		x.p('<p>', 'rcpv.term_row.fgcolor=' || rcpv.term_row.fgcolor);
		x.a('<a>', 'refresh', '@b.setting_form');
		if rcpv.term_row.bgcolor is not null then
			x.o('<style>');
			h.line('body{background-color:' || rcpv.term_row.bgcolor || '}');
			h.line('body{color:' || rcpv.term_row.fgcolor || '}');
			x.c('</style>');
		end if;
		x.p('<p>', 'The pattern in package RC will use result cache function to get versioned rowtype data,');
		x.p('<p>', ' and set them in package variable and avoid requent reads on table.');
		x.p('<p>',
				'This method will run well on both oracle 11.1 and 11.2, through they do differently for result cache dependency');
		x.o('<form name=f,action=term_b.setting_save,method=post>');
		t.split(tmp.stv, 'red,blue,green,silver,gray', ',');
		x.p('<label>', 'background-color');
		x.o('<select name=bgcolor>');
		m.w(' <option ?selected value="@">@</options>', tmp.stv, tmp.stv, rcpv.term_row.bgcolor);
		x.c('</select>');
		x.t('<br/>');
		x.p('<label>', 'foreground-color');
		x.o('<select name=fgcolor>');
		m.w(' <option ?selected value="@">@</options>', tmp.stv, tmp.stv, rcpv.term_row.fgcolor);
		x.c('</select>');
		x.t('<br/>');
		x.s(' <input type=submit>');
		x.c('</form>');
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
		h.gol('@b.setting_form');
	end;

end term_b;
/
