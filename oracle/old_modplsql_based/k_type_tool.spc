create or replace package k_type_tool is

  type col is record(
    item varchar2(2000));

  function d2s(p_date date) return varchar2;

  function dt2s(p_date date) return varchar2;

  function s2d(p_date varchar2) return date;

  function s2dt(p_date varchar2) return date;

  function get_empty_vcarr return owa.vc_arr;

  procedure half(p_str   varchar2,
                 p_left  in out nocopy varchar2,
                 p_right in out nocopy varchar2);

  function gen_token(p_algorithm binary_integer := 0) return varchar2;

  function ps(tpl in varchar2, subs varchar2) return varchar2;

  function ps(pat varchar2, vals st, ch char := ':') return varchar2;

  -- like c's printf, use ~ for replacement by default
  function pf(pat varchar2, sub varchar2, ch char := '~') return varchar2;
  function pf(pat varchar2, subs st, ch char := '~') return varchar2;

  function lspace(p varchar2, s varchar2 := ' ') return varchar2;

  function tf(cond boolean, t varchar2, f varchar2 := '') return varchar2;

  function nnpre(pre varchar2, str varchar2) return varchar2;

  function nvl2(cond varchar2, nn varchar2, n varchar2 := '') return varchar2;

  procedure split(stv in out nocopy st, p varchar2, sep varchar2 := ',');

  function join(stv in out nocopy st, sep varchar2 := ',') return varchar2;
  function joinc(stv st, sep varchar2 := ',') return varchar2;

  procedure gen_seq_list(amount pls_integer, ntv in out nocopy nt);

end k_type_tool;
/

