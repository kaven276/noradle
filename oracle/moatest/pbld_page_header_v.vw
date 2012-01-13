create or replace view pbld_page_header_v as
select "SCHEMA","PAGE","TITLE","CSS","JS","ANYTEXT" from pbld_page_header t where t.schema = user;

