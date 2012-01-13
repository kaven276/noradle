create or replace package psp_code_gen_b is

	procedure form_handler
	(
		name_array  owa.vc_arr,
		value_array owa.vc_arr
	);

end psp_code_gen_b;
/

