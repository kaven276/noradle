create or replace package body negotiation_b is

	procedure greece_text is
	begin
		if instr(r.header('accept-language'), 'el-GR') = 0 then
			h.sts_406_not_acceptable;
			p.h;
			src_b.link_proc;
			p.p('This page is for Greece reader only, You browser accepts "' || r.header('Accept-Language') || '" only.');
		else
			p.h;
			src_b.link_proc;
			p.p('OK, This page have Greece charracters your browser accept.');
			p.p('αβγδεζηθικλμνξξοορστυφχψω');
		end if;
		p.p('If the request''s accept headers can not be supported, return 406 not acceptable is ok.');
	end;

end negotiation_b;
/
