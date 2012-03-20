create or replace trigger t_user
  after update on user_t  
  for each row
declare
	-- local variables here
begin
	kv.del('user', :old.name);
end t_user;
/
