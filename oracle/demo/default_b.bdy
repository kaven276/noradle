create or replace package body default_b is

	procedure d is
	begin
		x.t('<!DOCTYPE html>');
		x.o('<html>');
		x.o(' <head>');
		x.p('  <style>', 'body,iframe{margin:0;padding:0;width:100%;height:100%;border:none;');
		x.p('  <script>',
				'window.onbeforeunload=function(e){
				return "Are you sure you will quit this noradle demo?";
				};');
		x.c(' </head>');
		x.o(' <body>');
		x.j('  <iframe>', '@b.list');
		x.c(' </body>');
		x.c('</html>');
	end;

	procedure list is
	begin
		x.p('<p>', x.a('<a>', 'view packages', 'po_content_b.packages'));
		x.p('<p>', x.a('<a target=_blank>', 'index_b.frame', 'index_b.frame'));
	end;

end default_b;
/
