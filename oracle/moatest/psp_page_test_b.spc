create or replace package psp_page_test_b is

	-- Author  : ADMINISTRATOR
	-- Created : 2009-10-23 14:53:14
	-- Purpose :

	procedure para_form(p_page varchar2);

	procedure save_para_and_go
	(
		name_array  owa.vc_arr,
		value_array owa.vc_arr
	);

end psp_page_test_b;
/

