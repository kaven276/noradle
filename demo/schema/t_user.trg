create or replace trigger t_user
  after update on user_t  
  for each row
begin
	r.del('s$user_rctime');
end t_user;
/
