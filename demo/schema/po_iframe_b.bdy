create or replace package body po_iframe_b is

	procedure main is
	begin
		x.t('<!DOCTYPE html>');
		x.o('<html>');
		x.o(' <head>');
		x.p('  <style>', 'body,iframe{margin:0;padding:0;width:100%;height:100%;border:none;');
		x.c(' </head>');
		x.o(' <body>');
		x.j('  <iframe>', 'po_content_b.packages');
		x.c(' </body>');
		x.c('</html>');
	end;

end po_iframe_b;
/
