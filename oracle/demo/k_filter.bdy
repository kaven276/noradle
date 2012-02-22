create or replace package body k_filter is

	procedure before is
	begin
		pv.id  := 'liyong';
		pv.now := sysdate;
    g.filter_pass;
	
		if true then
			h.header_close;
			p.init;
			p.h;
			p.p('execute in k_filter.before only, cancel execute the main prog');
			g.finish;
		end if;
	end;

	procedure after is
	begin
		null;
	end;

end k_filter;
/
