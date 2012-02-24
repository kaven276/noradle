create or replace package k_cache_cfg is

  function max_age(p_mime_type varchar2) return number;

  function safe_time return date;

  function instant_gac return boolean;

end k_cache_cfg;
/

