create or replace package k_traffic is

  procedure set_trace(p_info varchar2);

  procedure set_traffic_id(p_id varchar2);

  procedure set_bind_id(p_id varchar2);

  procedure log(p_size number);

end k_traffic;
/

