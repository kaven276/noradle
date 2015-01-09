create or replace package body negotiation_b is

	procedure languages_by_browser is
	begin
		if instr(r.header('accept-language'), 'el') > 0 then
			pc.h;
			src_b.link_proc;
			x.p('<p>', 'OK, This page have Greece charracters your browser accept.');
			x.p('<p>',
					utl_i18n.raw_to_nchar('CEB1CEB2CEB3CEB4CEB5CEB6CEB7CEB8CEB9CEBACEBBCEBCCEBDCEBECEBECEBFCEBFCF81CF83CF84CF85CF86CF87CF88CF89',
																'UTF8'));
		elsif instr(r.header('accept-language'), 'zh') > 0 then
			pc.h;
			src_b.link_proc;
			x.p('<p>', 'OK, This page have chinese charracters your browser accept.');
			x.p('<p>',
					utl_i18n.raw_to_nchar('E5A4A7E5AEB6E5A5BDEFBC8CE8BF99E698AFE4B8ADE69687E78988E7BD91E9A1B5E38082', 'AL32UTF8'));
		else
			h.sts_406_not_acceptable;
			pc.h;
			src_b.link_proc;
			x.p('<p>',
					'This page is for Greece reader only, You browser accepts "' || r.header('Accept-Language') || '" only.');
		end if;
		x.p('<p>', 'If the request''s accept headers can not be supported, return 406 not acceptable is ok.');
		x.p('<p>', 'set your browser language to have zh(chinese), el(greece) to see versions of the page.');
	end;

end negotiation_b;
/
