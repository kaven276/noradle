create or replace package k_ccflag is

	debug constant pls_integer := 0;

	config_mode constant pls_integer := 0;

	cm_sys constant pls_integer := 2;

	cm_pck constant pls_integer := 1;

	cm_def constant pls_integer := 0;

	xhtml_check_printing constant boolean := true;

	xhtml_check_xmlschema constant boolean := false;

	xml_check constant boolean := false;

	use_time_stats constant boolean := true;

end k_ccflag;
/
