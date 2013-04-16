create or replace package body filter_b is

	procedure see_filter is
	begin
		p.h;
		src_b.link_proc;
		p.hn(3, 'This page show package variables set by k_filter');
		p.p('You can use k_filter.before, k_filter.alfter to hook into the page to do pre/post processing');
		p.p('pv.id = ' || pv.id);
		p.p('pv.now = ' || t.dt2s(pv.now));
	end;

end filter_b;
/
