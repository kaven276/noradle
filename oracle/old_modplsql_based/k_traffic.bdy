create or replace package body k_traffic is

  gv_bind_id data_traffic_t.bind_id%type;

  gv_trace varchar2(2000);

  procedure set_trace(p_info varchar2) is
  begin
    gv_trace := nvl(p_info, ' ');
  end;

  procedure set_traffic_id(p_id varchar2) is
  begin
    k_traffic.set_bind_id(p_id);
  end;

  procedure log is
  begin
    if gv_trace is not null then
      dbms_pipe.pack_message('PATH: ' || r.cgi('PATH_INFO') || '?' || r.cgi('query_string'));
      dbms_pipe.pack_message('SIZE: ' || dbms_lob.getlength(wpg_docload.v_blob));
      dbms_pipe.pack_message('INFO: ' || gv_trace);
      dbms_pipe.pack_message('CACHE: ' || k_http.get_cache_str);
      p.i := dbms_pipe.send_message(lower(user) || '_access_trace');
    end if;

    if wpg_docload.v_blob is not null then
      k_traffic.log(dbms_lob.getlength(wpg_docload.v_blob));
    end if;

  end;

  procedure set_bind_id(p_id varchar2) is
  begin
    gv_bind_id := p_id;
  end;

  procedure log(p_size number) is
    v data_traffic_t%rowtype;
  begin
    if gv_bind_id is null then
      return;
    end if;
    v.dad     := r.cgi('dad_name');
    v.bind_id := gv_bind_id;
    select max(a.month_size)
      into v.month_size
      from data_traffic_t a
     where a.dad = v.dad
       and a.bind_id = v.bind_id;
    if v.month_size is null then
      v.first_time := sysdate;
      v.hist_size  := 0;
      v.month_size := 0;
      v.days       := 0;
      insert into data_traffic_t values v;
    end if;
    update data_traffic_t a
       set a.last_time  = sysdate,
           a.month_size = a.month_size + p_size,
           a.days = a.days + case
                      when trunc(a.last_time) = trunc(sysdate) then
                       0
                      else
                       1
                    end
     where a.dad = v.dad
       and a.bind_id = v.bind_id;
  end;

  procedure month_close is
  begin
    -- 如果不是再月份第一天0点左右10分钟执行,则忽略
    if to_char(sysdate + 10 / 24 / 60, 'd') != '0' then
      return;
    end if;
    if abs(sysdate - round(sysdate)) * 24 * 60 > 10 then
      return;
    end if;
    update data_traffic_t a set a.hist_size = a.hist_size + a.month_size, a.month_size = 0;
  end;

end k_traffic;
/

