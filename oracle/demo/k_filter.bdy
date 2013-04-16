create or replace package body k_filter is

	procedure before is
	begin
		p.format_src;
		-- h.set_line_break(null);
		pv.id  := 'liyong';
		pv.now := sysdate;
	
		if s.logged then
			auth_b.check_update;
		end if;
	
		g.filter_pass;
	
		if true then
			p.h;
			p.p('execute in k_filter.before only, cancel execute the main prog');
			g.cancel;
		end if;
	end;

	procedure after is
		pragma autonomous_transaction;
	begin
		if r.prog = 'filter_b.see_filter' then
			p.hn(3, 'k_filter.after write here. Exiting?');
			p.hn(3, 'k_filter.after can be used to do logging using autonomous_transaction');
		end if;
	end;

end k_filter;
/
