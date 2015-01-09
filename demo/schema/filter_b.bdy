create or replace package body filter_b is

	procedure see_filter is
	begin
		pc.h;
		src_b.link_proc;
		x.p('<h3>', 'This page show package variables set by k_filter');
		x.p('<p>', 'You can use k_filter.before, k_filter.alfter to hook into the page to do pre/post processing');
		x.p('<p>', 'pv.id = ' || pv.id);
		x.p('<p>', 'pv.now = ' || t.dt2s(pv.now));
	end;

end filter_b;
/
