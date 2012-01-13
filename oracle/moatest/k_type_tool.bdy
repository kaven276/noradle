create or replace package body k_type_tool is

  function d2s(p_date date) return varchar2 is
  begin
    return to_char(p_date, 'yyyy-mm-dd');
  end;

  function dt2s(p_date date) return varchar2 is
  begin
    return to_char(p_date, 'yyyy-mm-dd hh24:mi:ss');
  end;

  function s2d(p_date varchar2) return date is
  begin
    return to_date(trim(p_date), 'yyyy-mm-dd');
  end;

  function s2dt(p_date varchar2) return date is
  begin
    return to_date(trim(p_date), 'yyyy-mm-dd hh24:mi:ss');
  end;

  function get_empty_vcarr return owa.vc_arr is
    v_arr owa.vc_arr;
  begin
    return v_arr;
  end;

  procedure half(p_str   varchar2,
                 p_left  in out nocopy varchar2,
                 p_right in out nocopy varchar2) is
    v_pos pls_integer;
  begin
    v_pos := instr(p_str, ',');
    if v_pos > 0 then
      p_left  := substr(p_str, 1, v_pos - 1);
      p_right := substr(p_str, v_pos + 1);
    else
      p_left  := p_str;
      p_right := '';
    end if;
  end;

  function gen_token(p_algorithm binary_integer := 0) return varchar2 is
  
    v_seed        varchar2(80) := '12345678901234567890123456789012345678901234567890123456789012345678901234567890';
    v_algorithm   binary_integer := 2; -- 16 bytes key
    v_time        char(6);
    v_token       varchar2(100);
    v_ip_str      varchar2(200);
    v_ip_arry     owa_util.vc_arr;
    v_start_place number;
    v_end_place   number;
  begin
    v_ip_str      := owa_util.get_cgi_env('REMOTE_ADDR');
    v_start_place := 0;
    v_end_place   := instr(v_ip_str, '.');
    for i in 1 .. 3 loop
      v_ip_arry(i) := substr(v_ip_str,
                             v_start_place + 1,
                             v_end_place - v_start_place - 1);
      v_start_place := v_end_place;
      v_end_place := instr(v_ip_str, '.', v_start_place + 1);
    end loop;
    v_ip_arry(4) := substr(v_ip_str, v_start_place + 1);
    v_ip_str := '';
    for i in 1 .. 4 loop
      v_ip_str := substrb(rawtohex(utl_raw.cast_from_binary_integer(v_ip_arry(i))),
                          7) || v_ip_str;
    end loop;
    v_time  := to_char(sysdate, 'mmhhss');
    v_token := sys.dbms_obfuscation_toolkit_ffi.getkey(algorithm => v_algorithm,
                                                       seed      => utl_raw.cast_to_raw(v_seed));
    return v_token || v_time || v_ip_str;
  end;

  function ps(tpl varchar2, subs varchar2) return varchar2 is
    v_pos1 pls_integer := 0;
    v_pos2 pls_integer;
    v_cnt  pls_integer := 0;
    v_rtn  varchar2(2000);
    v_str  varchar2(100);
  begin
    if subs is null then
      return tpl;
    end if;
    loop
      v_pos2 := instr(subs, ',', v_pos1 + 1);
      if v_pos1 = 0 then
        if v_pos2 = 0 then
          return replace(tpl, '$1', subs);
        else
          v_rtn := tpl;
        end if;
      elsif v_pos2 = 0 then
        v_str := substr(subs, v_pos1 + 1);
        return replace(v_rtn, '$' || (v_cnt + 1), v_str);
      end if;
      v_cnt  := v_cnt + 1;
      v_str  := substr(subs, v_pos1 + 1, v_pos2 - v_pos1 - 1);
      v_rtn  := replace(v_rtn, '$' || v_cnt, v_str);
      v_pos1 := v_pos2;
    end loop;
  end;

  function ps(pat varchar2, vals st, ch char := ':') return varchar2 is
    v_str varchar2(32000) := pat;
    v_chr char(1) := chr(0);
    v_url boolean;
  begin
    for i in 1 .. vals.count loop
      v_str := replace(v_str, ch || i, v_chr || vals(i));
    end loop;
    return replace(v_str, v_chr, '');
  end;

  -- like c's printf, use ~ for replacement by default
  function pf(pat varchar2, sub varchar2, ch char := '~') return varchar2 is
  begin
    return replace(pat, ch, sub);
  end;

  function pf(pat varchar2, subs st, ch char := '~') return varchar2 is
    v_rtn varchar2(32000);
  begin
    v_rtn := regexp_replace(pat, ch, subs(1), 1);
    for i in 2 .. subs.count loop
      v_rtn := regexp_replace(v_rtn, ch, subs(1), 1);
    end loop;
    return v_rtn;
  end;

  function lspace(p varchar2, s varchar2 := ' ') return varchar2 is
  begin
    return regexp_replace(p, '([^$])', '\1' || s);
  end;

  function tf(cond boolean, t varchar2, f varchar2) return varchar2 is
  begin
    if cond then
      return t;
    else
      return f;
    end if;
  end;

  function nnpre(pre varchar2, str varchar2) return varchar2 is
  begin
    if str is null then
      return null;
    end if;
    return pre || str;
  end;

  function nvl2(cond varchar2, nn varchar2, n varchar2) return varchar2 is
  begin
    if cond is not null then
      return nn;
    else
      return n;
    end if;
  end;

  procedure split(stv in out nocopy st, p varchar2, sep varchar2 := ',') is
    v_pos pls_integer;
    v_old pls_integer := 0;
    v_cnt pls_integer := 0;
  begin
    stv := st();
    if p is not null then
      stv.extend(regexp_count(p, sep) + 1);
      loop
        v_pos := instr(p, sep, v_old + 1, 1);
        exit when v_pos = 0 or v_pos is null;
        v_cnt := v_cnt + 1;
        stv(v_cnt) := trim(substr(p, v_old + 1, v_pos - v_old - 1));
        v_old := v_pos;
      end loop;
      stv(v_cnt + 1) := trim(substr(p, v_old + 1));
    end if;
  end;

  function join(stv in out nocopy st, sep varchar2 := ',') return varchar2 is
    s varchar2(32000);
  begin
    if stv is null or stv.count = 0 then
      return '';
    end if;
    s := stv(1);
    for i in 2 .. stv.count loop
      s := s || sep || stv(i);
    end loop;
    return s;
  end;

  function joinc(stv st, sep varchar2 := ',') return varchar2 is
    s varchar2(32000);
  begin
    if stv is null or stv.count = 0 then
      return '';
    end if;
    s := stv(1);
    for i in 2 .. stv.count loop
      s := s || sep || stv(i);
    end loop;
    return s;
  end;

  procedure gen_seq_list(amount pls_integer, ntv in out nocopy nt) is
  begin
    select rownum bulk collect
      into ntv
      from dual a
    connect by rownum <= amount;
  end;

end k_type_tool;
/

