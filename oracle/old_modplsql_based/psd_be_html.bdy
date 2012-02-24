create or replace package body psd_be_html is

	-- usage
	-- select psd_be_html.linkto('#caption','#object','#oowner','#oname','#otype','#subobject','#username') from dual

	function linkto
	(
		p_caption   varchar2,
		p_object    varchar2 := null,
		p_oowner    varchar2 := null,
		p_oname     varchar2 := null,
		p_otype     varchar2 := null,
		p_subobject varchar2 := null,
		p_username  varchar2 := null
	) return varchar2 is
		v_html   varchar2(32000) := '<script>window.navigate("[url]");</script>';
		v_prefix varchar2(1000);
		v_url    varchar2(2000);
	begin
		select max(t.url_prefix) into v_prefix from pbld_schema_config t where t.schema = user;
		if v_prefix is null then
			v_prefix := 'http://localhost/psp.web/' || lower(user) || '/';
		end if;
		case lower(p_caption)
			when 'all-in-one' then
				-- for the perticular all-in-one mode,
				-- filter in all available operations with psd be environment variables
				v_url := p.ps('psd_be_html.all_in_one?p_object=:1&p_oowner=:2&p_oname=:3&p_otype=:4&p_subobject=:5&p_username=:6',
											st(p_object, p_oowner, p_oname, p_otype, p_subobject, p_username));
			when 'dad_default_page' then
				select max(t.url_prefix) into v_prefix from pbld_schema_config t where t.schema = p_oname;
				if v_prefix is null then
					v_prefix := 'http://localhost/psp.web/' || lower(p_oname) || '/';
				end if;
				v_url := '';
			when 'page_all' then
				-- list all the be-html page's entries
				v_url := p.ps('psp_psdbe_all.page?p_page=:1.:2', st(p_oname, p_subobject));
			when 'package_all' then
				-- list all the be-html package's entries
				v_url := p.ps('psp_psdbe_all.package?p_page=#oname', st(p_oname));
			when 'test_page' then
				-- test the page in psd html embeded window
				v_url := p.ps('psp_page_test_b.para_form?p_page=:1.:2', st(p_oname, p_subobject));
			when 'header_config' then
				-- config page's html header part, for title,private css and js, etc..
				v_url := p.ps('psp_page_header_b.edit_form?p_page=:1.:2', st(p_oname, p_subobject));
			when 'config_authorize' then
				-- used for developer login
				-- developer login use basic authentication
				v_url := '';
			when 'config param' then
				-- config table column, for list/editing template, for example config label text
				v_url := '';
			when 'config table' then
				-- config table for qooo
				v_url := '';
			when 'config column' then
				-- config data item display/form setting
				v_url := '';
			when 'version_control' then
				-- get latest compiled versions
				-- mark/save a version and get mark history,
				-- label a version
				v_url := '';
		end case;
		return replace(v_html, '[url]', v_prefix || v_url);
	end;

	procedure all_in_one
	(
		p_object    varchar2 := null,
		p_oowner    varchar2 := null,
		p_oname     varchar2 := null,
		p_otype     varchar2 := null,
		p_subobject varchar2 := null,
		p_username  varchar2 := null
	) is
	begin
		null;
	end;

end psd_be_html;
/

