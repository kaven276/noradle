create or replace package proxy_b is

	procedure processor
	(
		name_array  owa.vc_arr,
		value_array owa.vc_arr
	);

	procedure main;

	procedure form;

end proxy_b;
/

