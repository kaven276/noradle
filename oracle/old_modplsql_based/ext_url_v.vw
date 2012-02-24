create or replace view ext_url_v as
select a.key, a.prefix
    from ext_url_t a
   where a.dbu = lower(sys_context('user','current_schema')) WITH CHECK option;

