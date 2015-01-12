create or replace package k_cfg is

	procedure server_control(p_cfg in out nocopy server_control_t%rowtype);

end k_cfg;
/
