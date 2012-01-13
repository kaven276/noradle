create or replace package ir_repeater is

	procedure trigger
	(
		p_tpl_schema   varchar2,
		p_trigger_name varchar2
	);

end ir_repeater;
/

