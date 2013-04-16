create or replace trigger t_user
  after update on user_t  
  for each row
begin
	kv.del('user', :old.name);
end t_user;
/
