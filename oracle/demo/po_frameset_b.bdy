create or replace package body po_frameset_b is

	procedure main is
	begin
		x.t('<!DOCTYPE html>');
		x.o('<html>');
		x.o(' <frameset>');
		x.j('  <frame>', 'po_content_b.packages');
		x.c(' </frameset>');
		x.c('</html>');
	end;

end po_frameset_b;
/
