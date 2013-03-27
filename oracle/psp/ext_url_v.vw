create or replace force view ext_url_v as
select a.key, a.prefix, a.prefix_https
    from ext_url_t a
   where a.dbu = lower(sys_context('user','current_schema')) WITH CHECK option;
